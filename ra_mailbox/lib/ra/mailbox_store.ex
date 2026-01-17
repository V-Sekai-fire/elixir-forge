defmodule RAMailbox.DETS.MailboxStore do
  @moduledoc """
  DETS-based mailbox store for persistent message operations.

  This GenServer provides persistent mailbox semantics using DETS:
  - put: Add message to user's mailbox queue
  - consume: Read and remove next message (queue semantics)
  - peek: Read-only peek at next message
  """

  use GenServer
  require Logger

  @table_name :mailbox_store
  @table_file 'mailbox_store.dets'

  @type user_id :: String.t()
  @type message :: any()

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting DETS Mailbox Store")

    case open_dets_table() do
      {:ok, _table} ->
        Logger.info("DETS mailbox store opened successfully")
        {:ok, %{table: @table_name}}

      {:error, reason} ->
        Logger.error("Failed to open DETS table: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("Closing DETS mailbox store")
    :dets.close(@table_name)
  end

  # Mailbox operations
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

  @impl true
  def handle_call({:put, user_id, message}, _from, state) do
    # Get current queue for user
    current_queue = get_user_queue(user_id)

    # Create mailbox message with metadata
    mailbox_message = %{
      id: make_ref(),
      timestamp: System.system_time(:millisecond),
      content: message
    }

    # Add to front of queue (newer messages first, consume from end)
    new_queue = [mailbox_message | current_queue]

    # Store back to DETS
    result = case :dets.insert(@table_name, {user_id, new_queue}) do
      :ok -> :ok
      error ->
        Logger.error("DETS insert failed: #{inspect(error)}")
        error
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:consume, user_id}, _from, state) do
    current_queue = get_user_queue(user_id)

    case Enum.reverse(current_queue) do  # Reverse to consume oldest first
      [] ->
        {:reply, {:error, :empty}, state}

      [oldest_message | remaining] ->
        # Put remaining messages back (in original order)
        remaining_queue = Enum.reverse(remaining)

        # Update DETS
        case :dets.insert(@table_name, {user_id, remaining_queue}) do
          :ok ->
            {:reply, {:ok, oldest_message}, state}

          error ->
            Logger.error("DETS consume update failed: #{inspect(error)}")
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:peek, user_id}, _from, state) do
    current_queue = get_user_queue(user_id)

    case Enum.reverse(current_queue) do  # Peek oldest first
      [] -> {:reply, {:error, :empty}, state}
      [oldest_message | _] -> {:reply, {:ok, oldest_message}, state}
    end
  end

  @impl true
  def handle_call({:get_count, user_id}, _from, state) do
    count = length(get_user_queue(user_id))
    {:reply, count, state}
  end

  # Helper functions
  defp open_dets_table do
    :dets.open_file(@table_name, [file: @table_file, type: :set])
  end

  defp get_user_queue(user_id) do
    case :dets.lookup(@table_name, user_id) do
      [] -> []
      [{^user_id, queue}] when is_list(queue) -> queue
      _ -> []
    end
  end

  # Public API for mailbox operations (used by Zenoh bridge)
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
end
