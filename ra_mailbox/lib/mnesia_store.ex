defmodule RAMailbox.MnesiaStore do
  @moduledoc """
  Mnesia-based durable mailbox store.

  This GenServer manages Mnesia operations for the mailbox service:
  - Creates and manages Mnesia table schema
  - Handles mailbox operations (put, consume, peek)
  - Ensures durability through disk replication
  """

  use GenServer
  require Logger

  @table_name :mailbox_messages
  @table_type :set  # For simple key-value operations

  # We'll use tuples for Mnesia records: {user_id, message_id, content, inserted_at}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Mnesia Mailbox Store")

    # Start Mnesia and initialize schema
    case init_mnesia() do
      :ok ->
        Logger.info("Mnesia mailbox store initialized successfully")
        {:ok, %{table: @table_name}}

      {:error, reason} ->
        Logger.error("Failed to initialize Mnesia: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("Shutting down Mnesia mailbox store")
    # Mnesia handles its own shutdown
  end

  # Public API - Mailbox Operations
  def put(user_id, message) do
    GenServer.call(__MODULE__, {:put, user_id, message})
  end

  def consume(user_id) do
    GenServer.call(__MODULE__, {:consume, user_id})
  end

  def peek(user_id) do
    GenServer.call(__MODULE__, {:peek, user_id})
  end

  def get_message_count(user_id) do
    GenServer.call(__MODULE__, {:get_count, user_id})
  end

  # Process commands (used by Zenoh bridge)
  def process_command({:put, user_id, message}) do
    case put(user_id, message) do
      :ok -> {:ok, :ok}
      error -> {:error, error}
    end
  end

  def process_command({:consume, user_id}) do
    consume(user_id)
  end

  def process_command({:peek, user_id}) do
    peek(user_id)
  end

  def process_command({:count, user_id}) do
    {:ok, get_message_count(user_id)}
  end

  # GenServer callbacks
  @impl true
  def handle_call({:put, user_id, message}, _from, state) do
    result = mnesia_put(user_id, message)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:consume, user_id}, _from, state) do
    result = mnesia_consume(user_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:peek, user_id}, _from, state) do
    result = mnesia_peek(user_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_count, user_id}, _from, state) do
    result = mnesia_count(user_id)
    {:reply, result, state}
  end

  # Mnesia Operations using compound keys: {user_id, message_id} -> {content, timestamp}
  # We'll store compound keys for efficient user-specific operations

  defp mnesia_put(user_id, message) do
    message_id = get_next_message_id(user_id)
    key = {user_id, message_id}
    value = {message, DateTime.utc_now()}

    :mnesia.transaction(fn ->
      :mnesia.write({@table_name, key, value})
      :ok
    end)
  rescue
    error ->
      Logger.error("Mnesia put failed: #{inspect(error)}")
      {:error, :write_failed}
  end

  defp mnesia_consume(user_id) do
    :mnesia.transaction(fn ->
      # Use select with guard to find user's messages, then pick first (oldest)
      pattern = {{@table_name, {user_id, :'$1'}, {:_, :_}}, [], [:'$$']}
      guards = []

      case :mnesia.select(@table_name, [{pattern, guards, [:'$_']}]) do
        [] ->
          :mnesia.abort(:empty)

        results when is_list(results) ->
          # Find message with lowest message_id (FIFO order)
          [oldest_record] = Enum.min_by(results, fn {key, _} ->
            {_, message_id} = key
            message_id
          end)

          # Delete the oldest record
          :mnesia.delete_object(oldest_record)
          {_, value} = oldest_record
          {content, _timestamp} = value
          {:ok, content}
      end
    end)
  rescue
    :empty -> {:error, :empty}
    error ->
      Logger.error("Mnesia consume failed: #{inspect(error)}")
      {:error, :consume_failed}
  end

  defp mnesia_peek(user_id) do
    :mnesia.transaction(fn ->
      # Same as consume but don't delete
      pattern = {{@table_name, {user_id, :'$1'}, {:_, :_}}, [], [:'$_']}
      guards = []

      case :mnesia.select(@table_name, [{pattern, guards, [:'$_']}]) do
        [] ->
          :mnesia.abort(:empty)

        results when is_list(results) ->
          [oldest_record] = Enum.min_by(results, fn {key, _} ->
            {_, message_id} = key
            message_id
          end)

          {_, value} = oldest_record
          {content, _timestamp} = value
          {:ok, content}
      end
    end)
  rescue
    :empty -> {:error, :empty}
    error ->
      Logger.error("Mnesia peek failed: #{inspect(error)}")
      {:error, :peek_failed}
  end

  defp mnesia_count(user_id) do
    # Count using select with guard
    pattern = {{@table_name, {user_id, :'$1'}, {:_, :_}}, [], [:'$_']}
    guards = []
    {:ok, :mnesia.select(@table_name, [{pattern, guards, [:'$$']}]) |> length}
  rescue
    error ->
      Logger.error("Mnesia count failed: #{inspect(error)}")
      0
  end

  # Helper functions
  defp get_next_message_id(user_id) do
    # Simple sequential ID generation
    # For production, use a proper counter/sequence
    case mnesia_count(user_id) do
      {:ok, count} -> count + 1
      count when is_integer(count) -> count + 1
    end
  end

  defp init_mnesia do
    # Ensure Mnesia application is started
    case :application.ensure_started(:mnesia) do
      {:error, reason} -> {:error, {:cannot_start_mnesia, reason}}
      :ok -> init_mnesia_schema()
    end
  end

  defp init_mnesia_schema do
    # Create schema if it doesn't exist
    case :mnesia.create_schema([node()]) do
      {:error, {_, {:already_exists, _}}} -> :ok  # Schema already exists
      :ok -> Logger.info("Created Mnesia schema")
      {:error, reason} -> {:error, {:schema_creation_failed, reason}}
    end

    # Start Mnesia
    case :mnesia.start() do
      :ok -> create_mailbox_table()
      {:error, reason} -> {:error, {:mnesia_start_failed, reason}}
    end
  end

  defp create_mailbox_table do
    # We'll use compound keys with tuple records
    # No additional attributes needed, just use tuple format
    table_options = [
      disc_copies: [node()]  # Durable disk copies
    ]

    case :mnesia.create_table(@table_name, table_options) do
      {:atomic, :ok} ->
        Logger.info("Created Mnesia mailbox table")
        wait_for_table()
      {:aborted, {:already_exists, @table_name}} ->
        Logger.info("Mailbox table already exists")
        wait_for_table()
      {:aborted, reason} ->
        {:error, {:table_creation_failed, reason}}
    end
  end

  defp wait_for_table do
    # Wait for table to be accessible on all nodes (important for distributed)
    case :mnesia.wait_for_tables([@table_name], 5000) do
      :ok ->
        Logger.info("Mnesia mailbox store ready")
        :ok
      {:timeout, _} ->
        {:error, :table_timeout}
      {:error, reason} ->
        {:error, {:table_wait_failed, reason}}
    end
  end

  # Administrative functions
  def reset do
    :mnesia.clear_table(@table_name)
  end

  def info do
    :mnesia.table_info(@table_name, :all)
  end

  def backup_to_file(filename) do
    :mnesia.backup(filename)
  end

  def restore_from_file(filename) do
    :mnesia.restore(filename, [])
  end
end
