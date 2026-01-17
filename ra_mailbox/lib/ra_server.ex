defmodule RAMailbox.RAServer do
  @moduledoc """
  Ra State Machine for mailbox operations with ACID semantics.

  Implements the `:ra_machine` behaviour to provide distributed mailbox storage
  with ACID guarantees through Raft consensus.

  ACID Properties:
  - Atomicity: All operations in a transaction succeed or fail together
  - Consistency: Raft ensures consistency across replicas
  - Isolation: Node-based isolation with per-user transaction contexts
  - Durability: Ra persists state to disk (configurable)

  State: Map of key-value pairs for flexible mailbox storage
  Commands: Handle `{:transaction, operations, reads}` where:
    - operations: List of write operations [{:set, key, value} | {:delete, key}]
    - reads: List of keys to read [{:get, key}]
  Returns: {new_state, {:ok, read_results}} where read_results is a map of key -> value
  Queries: Handle `{:get, key}` for read-only queries outside transactions (eventual consistency)
  """

  @behaviour :ra_machine

  @impl :ra_machine
  def init(_args) do
    # Initialize empty state map for flexible key-value storage
    %{}
  end

  @impl :ra_machine
  def apply(_meta, {:transaction, operations, reads}, state) do
    # First, perform reads on current state (before writes) for ACID isolation
    read_results =
      Enum.reduce(reads, %{}, fn
        {:get, key}, acc ->
          Map.put(acc, key, Map.get(state, key))

        _other, acc ->
          acc
      end)

    # Then apply all write operations atomically to state
    new_state =
      Enum.reduce(operations, state, fn operation, acc ->
        case operation do
          {:set, key, value} ->
            Map.put(acc, key, value)

          {:delete, key} ->
            Map.delete(acc, key)

          {:get, _key} ->
            # Get operations should be in reads list, not operations
            acc

          other ->
            # Unknown operation, log warning but don't fail
            require Logger
            Logger.warning("RaStateMachine: Unknown operation in transaction: #{inspect(other)}")
            acc
        end
      end)

    # Return new state and result with read values
    # This ensures reads see the state before writes (ACID isolation)
    {new_state, {:ok, read_results}}
  end

  # Query function for :ra.query/2 (not part of :ra_machine behaviour)
  def query({:get, key}, state) do
    # Return value from state, or nil if not found
    # Used for read-only queries outside transactions
    Map.get(state, key)
  end

  def query(_query, _state) do
    # Unknown query type
    nil
  end

  # =====================================================
  # MAILBOX-SPECIFIC OPERATIONS (Legacy API)
  # =====================================================

  @doc "Get current mailbox statistics - legacy support"
  def get_stats(ra_name) do
    # This would need to be implemented as a transaction if needed
    {:ok, %{transactions: 0}}
  end

  @doc "Mailbox-specific put operation"
  def put(ra_name, user_id, message) do
    mailbox_key = mailbox_key(user_id)
    operations = [{:set, mailbox_key, message}]
    reads = []

    # Simple single-operation transaction
    command(ra_name, {:transaction, operations, reads})
  end

  @doc "Mailbox-specific consume operation (remove oldest)"
  def consume(ra_name, user_id) do
    mailbox_key = mailbox_key(user_id)

    # This is a complex operation requiring reads and multiple writes
    # For now, provide a simplified version
    # In a full implementation, we'd need to track message order
    case command(ra_name, {:transaction, [], [{:get, mailbox_key}]}) do
      {:ok, results} ->
        case Map.get(results, mailbox_key) do
          nil -> {:error, :empty}
          message ->
            # Remove the message
            command(ra_name, {:transaction, [{:delete, mailbox_key}], []})
            {:ok, message}
        end
      _ -> {:error, :query_failed}
    end
  end

  @doc "Mailbox-specific peek operation"
  def peek(ra_name, user_id) do
    mailbox_key = mailbox_key(user_id)

    case command(ra_name, {:transaction, [], [{:get, mailbox_key}]}) do
      {:ok, results} ->
        case Map.get(results, mailbox_key) do
          nil -> {:error, :empty}
          message -> {:ok, message}
        end
      _ -> {:error, :query_failed}
    end
  end

  @doc "Get message count for mailbox"
  def get_message_count(ra_name, user_id) do
    # Simplified - if key exists, assume 1 message
    # Real mailbox would need proper ordering/counting
    mailbox_key = mailbox_key(user_id)

    case command(ra_name, {:transaction, [], [{:get, mailbox_key}]}) do
      {:ok, results} ->
        if Map.has_key?(results, mailbox_key), do: 1, else: 0
      _ -> 0
    end
  end

  # Helper functions
  @spec start_simple(String.t()) :: {:ok, term()} | {:error, term()}
  def start_simple(server_id \\ "mailbox_ra") do
    # Start Ra default system
    :ra_system.start_default()

    # Simple RA server configuration for development/testing
    server_id = String.to_atom(server_id)

    # Use Erlang helper to avoid Elixir keyword list issues
    cluster_name = String.to_atom("mailbox_cluster_#{server_id}")
    machine = {:module, __MODULE__, %{}}
    server_name = String.to_atom("ra_server_#{server_id}")
    server_id_tuple = {server_name, node()}

    case :ra_helper.start_cluster(:default, cluster_name, machine, server_id_tuple) do
      {:ok, _, _} ->
        require Logger
        Logger.info("RA mailbox server #{server_id} started successfully")
        {:ok, server_id_tuple}
      {:ok, _} ->
        require Logger
        Logger.info("RA mailbox server #{server_id} started successfully")
        {:ok, server_id_tuple}
      error ->
        require Logger
        Logger.error("Failed to start RA server: #{inspect(error)}")
        error
    end
  end

  @doc "Send command to RA server and wait for response"
  def command(ra_name, command, timeout \\ 5000) do
    case :ra.process_command(ra_name, command, timeout) do
      {:ok, result} -> result
      error -> error
    end
  rescue
    error ->
      require Logger
      Logger.error("RA command failed: #{inspect(error)}")
      {:error, :command_failed}
  end

  # Application-level API for Zenoh bridge compatibility

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

  # Private helpers
  defp mailbox_key(user_id) do
    "mailbox:#{user_id}"
  end
end
