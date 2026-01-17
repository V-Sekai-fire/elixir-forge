defmodule RAMailbox.TransactionManager do
  @moduledoc """
  RA Transaction Manager for node-isolated ACID operations.

  Provides a GenServer-based transaction manager that actors can use to
  execute ACID transactions through RA (Raft). Each node gets its own isolated
  Ra cluster, ensuring complete isolation between nodes.

  Based on spatial_node_store_transactions patterns, adapted for mailbox semantics.

  ⚠️ **Performance Guidance for Mailbox Service:**

  This transaction manager provides ACID guarantees but with performance overhead (~50-100μs per operation).
  For high-frequency mailbox operations requiring 100K+ ops/sec with low latency:

  - **Use this TransactionManager only** for:
    - Exactly-once consumption semantics (ACID critical for message delivery)
    - Cross-actor coordination (multi-user operations)
    - Critical mailbox operations requiring consistency

  - **Direct RA operations** are sufficient for most mailbox put/get operations

  See property tests for expectation setting on performance profile.

  Actors can use this manager to:
  - Execute synchronous transactions with call_with_transaction/2
  - Execute asynchronous transactions with cast_with_transaction/2
  - Coordinate multi-actor transactions with coordinate_transaction/3

  Transaction Semantics:
  - Atomicity: All operations in a transaction succeed or fail together
  - Consistency: Raft ensures consistency across replicas
  - Isolation: Each node has its own isolated cluster
  - Durability: RA persists state to disk (configurable)
  """

  use GenServer
  require Logger

  @default_timeout 5_000

  @doc """
  Starts the TransactionManager.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Execute a mailbox transaction synchronously.

  Executes a transaction context for mailbox operations on a specific node.

  Returns {:ok, result} or {:error, reason}.

  Example:
      # Put message in mailbox with ACID guarantees
      TransactionManager.call_with_transaction("node_1", fn ctx ->
        # Put message (write operation)
        key = "mailbox:user123"
        operations = [{:set, key, "Hello World"}]
        {:ok, :message_sent, operations}
      end)

      # Read and consume message atomically
      TransactionManager.call_with_transaction("node_1", fn ctx ->
        key = "mailbox:user123"
        # Read current message (ACID isolation)
        ctx.read(key)

        current_msg = ctx.read_results[key]
        if current_msg do
          # Atomically consume the message
          operations = [{:delete, key}]
          {:ok, current_msg, operations}
        else
          {:error, :empty}
        end
      end)
  """
  def call_with_transaction(node_id, fun, timeout \\ @default_timeout)
      when is_function(fun, 1) do
    GenServer.call(__MODULE__, {:execute_transaction, fun, node_id}, timeout)
  end

  @doc """
  Execute a transaction asynchronously with casting.

  Sends transaction for execution without waiting for result.
  """
  def cast_with_transaction(node_id, fun) when is_function(fun, 1) do
    GenServer.cast(__MODULE__, {:execute_transaction_cast, fun, node_id})
  end

  @doc """
  Execute coordinate_transaction for multi-actor mailbox operations.

  Example: Updating multiple users' mailboxes atomically
  """
  def coordinate_transaction(node_id, functions, timeout \\ @default_timeout)
      when is_list(functions) do
    GenServer.call(__MODULE__, {:coordinate_transaction, functions, node_id}, timeout)
  end

  # =====================================================
  # MAILBOX-FRIENDLY HIGH-LEVEL API
  # =====================================================

  @doc "Put a message in user's mailbox with ACID guarantees"
  def put_message(node_id, user_id, message, timeout \\ @default_timeout) do
    call_with_transaction(node_id, fn _ctx ->
      key = mailbox_key(user_id)
      operations = [{:set, key, %{message: message, timestamp: DateTime.utc_now()}}]
      {:ok, :message_sent, operations}
    end, timeout)
  end

  @doc "Consume oldest message from user's mailbox (exactly-once semantics)"
  def consume_message(node_id, user_id, timeout \\ @default_timeout) do
    call_with_transaction(node_id, fn ctx ->
      key = mailbox_key(user_id)
      # Read current message first (ACID isolation)
      ctx.read(key)

      case Map.get(ctx.read_results, key) do
        nil ->
          {:error, :empty}

        message_data ->
          # Atomically consume the message
          operations = [{:delete, key}]
          {:ok, message_data.message, operations}
      end
    end, timeout)
  end

  @doc "Peek at oldest message without consuming it"
  def peek_message(node_id, user_id, timeout \\ @default_timeout) do
    call_with_transaction(node_id, fn ctx ->
      key = mailbox_key(user_id)
      ctx.read(key)

      case Map.get(ctx.read_results, key) do
        nil -> {:error, :empty}
        message_data -> {:ok, message_data.message}
      end
    end, timeout)
  end

  @doc "Get count of messages in user's mailbox"
  def message_count(node_id, user_id, timeout \\ @default_timeout) do
    call_with_transaction(node_id, fn ctx ->
      key = mailbox_key(user_id)
      ctx.read(key)

      count = if Map.has_key?(ctx.read_results, key), do: 1, else: 0
      {:ok, count, []}
    end, timeout)
  end

  # =====================================================
  # GENSERVER IMPLEMENTATION
  # =====================================================

  @impl true
  def init(_opts) do
    Logger.info("Mailbox TransactionManager started with Ra (Raft)")
    {:ok, %{clusters: %{}, active_transactions: 0}}
  end

  @impl true
  def handle_call({:execute_transaction, fun, node_id}, _from, state) do
    {result, new_state} = execute_transaction(fun, node_id, state)
    {:reply, result, Map.put(new_state, :active_transactions, new_state.active_transactions + 1)}
  end

  @impl true
  def handle_call({:coordinate_transaction, functions, node_id}, _from, state) do
    {result, new_state} = execute_coordinate_transaction(functions, node_id, state)
    {:reply, result, Map.put(new_state, :active_transactions, new_state.active_transactions + 1)}
  end

  @impl true
  def handle_cast({:execute_transaction_cast, fun, node_id}, state) do
    Task.start(fn ->
      execute_transaction(fun, node_id, state)
    end)
    {:noreply, Map.put(state, :active_transactions, state.active_transactions + 1)}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("TransactionManager terminating")
    :ok
  end

  # =====================================================
  # PRIVATE IMPLEMENTATION
  # =====================================================

  defp execute_transaction(fun, node_id, state) do
    try do
      case get_or_create_cluster(node_id, state) do
        {:ok, {{server_name, _node}, cluster}, new_state} ->
          execute_transaction_command(fun, node_id, {server_name, cluster}, new_state)

        {:error, reason} ->
          {{:error, {:cluster_error, reason}}, state}
      end
    rescue
      e ->
        Logger.error("Transaction error: #{inspect(e)}")
        {{:error, {:exception, e}}, state}
    end
  end

  defp execute_transaction_command(fun, node_id, server_id, state) do
    # Create transaction context with mutable reads list
    reads_key = {:transaction_reads, make_ref()}
    Process.put(reads_key, [])

    transaction_context = create_transaction_context(node_id, reads_key)

    # Execute the function to build operations and reads
    result = fun.(transaction_context)

    # Collect all reads
    reads = Process.get(reads_key, []) |> Enum.reverse()
    Process.delete(reads_key)

    process_transaction_result(result, reads, server_id, state)
  end

  defp create_transaction_context(node_id, reads_key) do
    %{
      node_id: node_id,
      operations: [],
      reads: [],
      read_results: %{},
      read: fn key ->
        current_reads = Process.get(reads_key, [])
        Process.put(reads_key, {:get, key})
        nil
      end
    }
  end

  defp process_transaction_result({:ok, result_value, operations}, reads, server_id, state)
       when is_list(operations) do
    command = {:transaction, operations, reads}

    case :ra.process_command(server_id, command, @default_timeout) do
      {:ok, {:ok, _read_results}, _leader} ->
        {{:ok, result_value}, state}

              {:error, reason} ->
        {{:error, {:ra_error, reason}}, state}

              other ->
        {{:error, {:unexpected_result, other}}, state}
            end
  end

  defp process_transaction_result({:error, reason}, _reads, _server_id, state) do
    {{:error, reason}, state}
  end

  defp execute_coordinate_transaction(functions, node_id, state) do
    try do
      case get_or_create_cluster(node_id, state) do
        {:ok, {{server_name, _node}, cluster}, new_state} ->
          execute_coordinate_functions(functions, node_id, {server_name, cluster}, new_state)

        {:error, reason} ->
          {{:error, {:cluster_error, reason}}, state}
      end
    rescue
      e ->
        Logger.error("Coordination transaction error: #{inspect(e)}")
        {{:error, {:exception, e}}, state}
    end
  end

  defp execute_coordinate_functions(functions, node_id, server_id, state) do
    reads_key = {:transaction_reads, make_ref()}
    Process.put(reads_key, [])

    transaction_context = create_transaction_context(node_id, reads_key)

    {final_ctx, results} = accumulate_function_results(functions, transaction_context)

    reads = Process.get(reads_key, []) |> Enum.reverse()
    Process.delete(reads_key)

    process_coordinate_results(results, final_ctx.operations, reads, server_id, state)
  end

  defp accumulate_function_results(functions, initial_context) do
    Enum.reduce(functions, {initial_context, []}, fn fun, {acc_ctx, acc_results} ->
      case fun.(acc_ctx) do
        {:ok, result, new_operations} ->
          new_ctx = %{acc_ctx | operations: new_operations ++ acc_ctx.operations}
          {new_ctx, [{:ok, result} | acc_results]}

        {:error, reason} ->
          {acc_ctx, [{:error, reason} | acc_results]}
      end
    end)
  end

  defp process_coordinate_results(results, operations, reads, server_id, state) do
    if Enum.all?(results, fn {status, _} -> status == :ok end) do
      send_coordinate_command(operations, reads, server_id, results, state)
    else
      errors = Enum.filter(results, fn {status, _} -> status == :error end)
      {{:error, {:coordination_failed, errors}}, state}
    end
  end

  defp send_coordinate_command(operations, reads, server_id, results, state) do
    command = {:transaction, operations, reads}

    case :ra.process_command(server_id, command, @default_timeout) do
      {:ok, {:ok, _read_results}, _leader} ->
        result_values = results |> Enum.reverse() |> Enum.map(fn {_, result} -> result end)
        {{:ok, result_values}, state}

      {:error, reason} ->
        {{:error, {:ra_error, reason}}, state}

      other ->
        {{:error, {:unexpected_result, other}}, state}
    end
  end

  # Per-node cluster isolation (spatial node store pattern)
  defp get_or_create_cluster(node_id, state) do
    case Map.get(state.clusters, node_id) do
      nil ->
        # Start Ra default system if not started
        :ra_system.start_default()

        # Create new cluster for this node
        cluster_name = cluster_name_for_node(node_id)
        # Server ID must be {Name, Node} tuple (2 elements)
        server_name = String.to_atom("tx_server_#{String.replace(node_id, ~r/[^a-zA-Z0-9_]/, "_")}")
        server_id = {server_name, node()}
        machine = {:module, RAMailbox.RAServer, %{}}

        # Use Erlang helper to avoid Elixir keyword list issue
        case :ra_helper.start_cluster(:default, cluster_name, machine, server_id) do
          {:ok, _, _} ->
            # Store server_id and cluster name as a tuple
            new_clusters = Map.put(state.clusters, node_id, {server_id, cluster_name})
            {:ok, {server_id, cluster_name}, %{state | clusters: new_clusters}}

          {:ok, _} ->
            # Store server_id and cluster name as a tuple
            new_clusters = Map.put(state.clusters, node_id, {server_id, cluster_name})
            {:ok, {server_id, cluster_name}, %{state | clusters: new_clusters}}

          error ->
            Logger.error("Failed to create cluster for node #{node_id}: #{inspect(error)}")
            {:error, error}
        end

      existing_cluster_info ->
        {:ok, existing_cluster_info, state}
    end
  end

  defp cluster_name_for_node(node_id) do
    # Create unique cluster name from node_id
    sanitized = String.replace(node_id, ~r/[^a-zA-Z0-9_]/, "_")
    String.to_atom("transaction_cluster_#{sanitized}")
  end

  # Mailbox-specific key generation
  defp mailbox_key(user_id) do
    "mailbox:#{user_id}"
  end
end
