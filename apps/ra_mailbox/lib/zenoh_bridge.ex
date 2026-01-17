defmodule RAMailbox.ZenohBridge do
  @moduledoc """
  Zenoh-RA Bridge that connects Zenoh queries to RA linearizable operations.

  This bridge:
  1. Opens a Zenoh session and declares queryable for "forge/mailbox/*"
  2. Translates Zenoh key semantics to RA operations
  3. Forwards commands to RA cluster for consensus/linearizability
  4. Returns results via Zenoh replies
  """

  use GenServer
  require Logger

  @zenoh_key_pattern "forge/mailbox/*"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Zenoh-DETS Mailbox Bridge")

    with {:ok, session_id} <- Zenohex.Session.open(),
         {:ok, queryable_id} <- declare_queryable(session_id) do
      Logger.info("Zenoh queryable declared for: #{inspect(@zenoh_key_pattern)}")

      {:ok,
       %{
         session_id: session_id,
         queryable_id: queryable_id
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to initialize Zenoh bridge: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp declare_queryable(session_id) do
    Zenohex.Session.declare_queryable(session_id, @zenoh_key_pattern, self())
  end

  @impl true
  def terminate(reason, %{session_id: session_id, queryable_id: queryable_id}) do
    Logger.warning("Zenoh-RA Bridge terminating: #{inspect(reason)}")
    # Clean up Zenoh resources
    Zenohex.Queryable.undeclare(queryable_id)
    Zenohex.Session.close(session_id)
  end

  # Handle Zenoh query messages via process mailbox
  @impl true
  def handle_info(%Zenohex.Query{} = query, state) do
    handle_zenoh_query(query)
    {:noreply, state}
  end

  # Handle incoming Zenoh queries
  def handle_zenoh_query(query) do
    key_expr = query.key_expr
    Logger.debug("Received Zenoh query: #{key_expr}")

    # Parse key_expr: "forge/mailbox/[user_id]/[operation]"
    case String.split(key_expr, "/", parts: 5) do
      ["forge", "mailbox", user_id, operation] ->
        handle_mailbox_operation(user_id, operation, query)

      ["forge", "mailbox", user_id] ->
        # Default operation is consume (mailbox semantics)
        handle_mailbox_operation(user_id, "consume", query)

      _other ->
        Logger.warning("Invalid Zenoh key pattern: #{key_expr}")
        reply_error(query, "Invalid key pattern")
    end
  end

  # Handle mailbox operations
  def handle_mailbox_operation(user_id, operation, query) do
    payload = extract_payload(query)

    case build_ra_command(operation, user_id, payload) do
      {:ok, ra_command} ->
        execute_and_reply(ra_command, query)

      {:error, reason} ->
        reply_error(query, reason)
    end
  end

  defp extract_payload(query) do
    case query.payload do
      nil -> nil
      data -> Jason.decode!(data)
    end
  end

  defp build_ra_command("put", user_id, payload) when payload != nil do
    {:ok, {:put, user_id, payload}}
  end

  defp build_ra_command("consume", user_id, _payload) do
    {:ok, {:consume, user_id}}
  end

  defp build_ra_command("peek", user_id, _payload) do
    {:ok, {:peek, user_id}}
  end

  defp build_ra_command("count", user_id, _payload) do
    {:ok, {:count, user_id}}
  end

  defp build_ra_command(operation, _user_id, _payload) do
    Logger.warning("Unknown operation: #{operation}")
    {:error, "Unknown or invalid operation"}
  end

  defp execute_and_reply(ra_command, query) do
    case submit_to_ra(ra_command, nil) do
      {:ok, result} ->
        reply_success(query, result)

      {:error, reason} ->
        reply_error(query, reason)
    end
  end

  # Submit command directly to RA server (distributed ACID operations)
  def submit_to_ra(command, _ra_servers) do
    try do
      RAMailbox.RAServer.process_command(command)
    catch
      error ->
        Logger.error("RA server communication error: #{inspect(error)}")
        {:error, "RA server communication error: #{inspect(error)}"}
    end
  end

  # Reply functions
  def reply_success(query, result) do
    # Encode result as JSON for consistency
    json_response = Jason.encode!(%{status: "success", result: result})
    Zenohex.Query.reply(query, query.key_expr, json_response)
  end

  def reply_error(query, reason) do
    error_response = Jason.encode!(%{status: "error", reason: reason})
    Zenohex.Query.reply(query, query.key_expr, error_response)
  end
end
