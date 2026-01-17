defmodule RAMailbox.RAServer do
  @moduledoc """
  RA (Raft) server for linearizable mailbox operations.

  This RA server provides ACID mailbox operations with strong consistency
  guarantees across distributed Erlang nodes.
  """

  @type user_id :: String.t()
  @type message :: any()
  @type command :: {:put, user_id, message} | {:consume, user_id} | {:peek, user_id}

  # RA Machine callbacks - simplified for working version
  def init(_config) do
    # State contains mailboxes map: %{user_id => [message]}
    %{mailboxes: %{}, stats: %{puts: 0, consumes: 0, peeks: 0}}
  end

  # Simplified apply function for RA
  def apply(_meta, command, _effects, state) do
    case command do
      {:put, user_id, message} ->
        # Add message to user mailbox (FIFO: new messages at end)
        new_mailboxes = Map.update(state.mailboxes, user_id, [message], fn msgs ->
          msgs ++ [message]  # Append to maintain FIFO order
        end)

        new_state = %{state | mailboxes: new_mailboxes,
                            stats: Map.update!(state.stats, :puts, &(&1 + 1))}

        {state, :ok}

      {:consume, user_id} ->
        # Remove and return oldest message (FIFO)
        case Map.get(state.mailboxes, user_id, []) do
          [] ->
            {state, {:error, :empty}}

          [oldest | rest] ->
            new_mailboxes = if rest == [],
                               do: Map.delete(state.mailboxes, user_id),
                               else: Map.put(state.mailboxes, user_id, rest)

            new_state = %{state | mailboxes: new_mailboxes,
                                stats: Map.update!(state.stats, :consumes, &(&1 + 1))}

            {new_state, {:ok, oldest}}
        end

      {:peek, user_id} ->
        # Return oldest message without removing
        case Map.get(state.mailboxes, user_id, []) do
          [] ->
            {state, {:error, :empty}}

          [oldest | _rest] ->
            new_state = %{state | stats: Map.update!(state.stats, :peeks, &(&1 + 1))}
            {new_state, {:ok, oldest}}
        end

      {:count, user_id} ->
        # Get mailbox message count
        count = length(Map.get(state.mailboxes, user_id, []))
        {state, count}

      _unknown_command ->
        {state, {:error, :unknown_command}}
    end
  end

  # Administrative functions

  @doc "Get current mailbox statistics"
  def get_stats(ra_name) do
    case query(ra_name, :get_stats) do
      {:ok, result} -> result
      error -> error
    end
  end

  @doc "Reset all mailbox data"
  def reset(ra_name) do
    command(ra_name, :reset)
  end

  @doc "Get all user IDs with messages"
  def get_all_users(ra_name) do
    query(ra_name, :get_all_users)
  end

  # Helper functions for common applications
  @spec start_simple(String.t()) :: {:ok, term()} | {:error, term()}
  def start_simple(server_id \\ "mailbox_ra") do
    # Simple RA server configuration for development/testing
    server_id = String.to_atom(server_id)

    config = %{
      name: server_id,
      machine: {:module, __MODULE__, %{}},
      data_dir: 'priv/ra'
    }

    case :ra.start_server(config) do
      {:ok, _} ->
        Logger.info("RA mailbox server #{server_id} started successfully")
        {:ok, server_id}
      error ->
        Logger.error("Failed to start RA server: #{inspect(error)}")
        error
    end
  end

  @spec put(atom(), user_id(), message()) :: :ok | {:error, term()}
  def put(ra_name, user_id, message) do
    command(ra_name, {:put, user_id, message})
  end

  @spec consume(atom(), user_id()) :: {:ok, message()} | {:error, :empty} | {:error, term()}
  def consume(ra_name, user_id) do
    command(ra_name, {:consume, user_id})
  end

  @spec peek(atom(), user_id()) :: {:ok, message()} | {:error, :empty} | {:error, term()}
  def peek(ra_name, user_id) do
    command(ra_name, {:peek, user_id})
  end

  @spec get_message_count(atom(), user_id()) :: non_neg_integer()
  def get_message_count(ra_name, user_id) do
    query(ra_name, {:count, user_id})
  catch
    _ -> 0
  end

  @doc "Send command to RA server and wait for response"
  def command(ra_name, command, timeout \\ 5000) do
    case :ra.process_command(ra_name, command, timeout) do
      {:ok, result} -> result
      error -> error
    end
  rescue
    error ->
      Logger.error("RA command failed: #{inspect(error)}")
      {:error, :command_failed}
  end

  @doc "Query RA server state"
  def query(ra_name, query, timeout \\ 5000) do
    case :ra.process_command(ra_name, query, timeout) do
      {:ok, result} -> result
      error -> error
    end
  rescue
    error ->
      Logger.error("RA query failed: #{inspect(error)}")
      {:error, :query_failed}
  end

  # Application-level API for Zenoh bridge

  @doc """
  Process command for Zenoh bridge - matches MnesiaStore API
  """
  def process_command({:put, user_id, message}) do
    case put(:mailbox_ra, user_id, message) do
      :ok -> {:ok, :ok}
      error -> {:error, error}
    end
  end

  def process_command({:consume, user_id}) do
    consume(:mailbox_ra, user_id)
  end

  def process_command({:peek, user_id}) do
    peek(:mailbox_ra, user_id)
  end

  def process_command({:count, user_id}) do
    {:ok, get_message_count(:mailbox_ra, user_id)}
  end
end
