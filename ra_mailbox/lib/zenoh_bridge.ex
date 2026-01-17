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

    case Zenohex.open() do
      {:ok, session} ->
        case Zenohex.Session.declare_queryable(session, @zenoh_key_pattern) do
          {:ok, queryable} ->
            Logger.info("Zenoh queryable declared for: #{inspect(@zenoh_key_pattern)}")

            # Start bridge loop
            spawn_link(fn -> bridge_loop(session, queryable) end)

            {:ok, %{
              session: session,
              queryable: queryable
            }}

          {:error, reason} ->
            Logger.error("Failed to declare Zenoh queryable: #{inspect(reason)}")
            {:stop, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to open Zenoh session: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def terminate(reason, %{session: session}) do
    Logger.warn("Zenoh-RA Bridge terminating: #{inspect(reason)}")
    # Clean up Zenoh session
    Zenohex.Session.close(session)
  end

  # Bridge loop for processing Zenoh queries
  defp bridge_loop(session, queryable) do
    Zenohex.Queryable.loop(queryable, fn query ->
      handle_zenoh_query(query)
    end)
  rescue
    error ->
      Logger.error("Bridge loop crashed: #{inspect(error)}")
      Process.sleep(1000)
      bridge_loop(session, queryable)
  end

  # Handle incoming Zenoh queries
  def handle_zenoh_query(query) do
    key_expr = Zenohex.Query.key_expr(query)
    Logger.debug("Received Zenoh query: #{key_expr}")

    # Parse key_expr: "forge/mailbox/[user_id]/[operation]"
    case String.split(key_expr, "/", parts: 5) do
      ["forge", "mailbox", user_id, operation] ->
        handle_mailbox_operation(user_id, operation, query)

      ["forge", "mailbox", user_id] ->
        # Default operation is consume (mailbox semantics)
        handle_mailbox_operation(user_id, "consume", query)

      _other ->
        Logger.warn("Invalid Zenoh key pattern: #{key_expr}")
        reply_error(query, "Invalid key pattern")
    end
  end

  # Handle mailbox operations
  def handle_mailbox_operation(user_id, operation, query) do
    # Extract payload if present
    payload = case Zenohex.Query.payload(query) do
      {:ok, data} -> Jason.decode!(data)
      _ -> nil
    end

    # Map operation to RA command
    ra_command = case operation do
      "put" when payload != nil ->
        {:put, user_id, payload}

      "consume" ->
        {:consume, user_id}

      "peek" ->
        {:peek, user_id}

      "count" ->
        # Special operation to get mailbox count
        {:count, user_id}

      _ ->
        Logger.warn("Unknown operation: #{operation}")
        nil
    end

    # Execute DETS command and reply
    if ra_command do
      case submit_to_ra(ra_command, nil) do
        {:ok, result} ->
          reply_success(query, result)
        {:error, reason} ->
          reply_error(query, reason)
      end
    else
      reply_error(query, "Unknown or invalid operation")
    end
  end

  # Submit command to RA cluster supervisor
  def submit_to_ra(command, _ra_servers) do
    # Use RA cluster for linearizable mailbox operations
    try do
      RAMailbox.RAClusterSupervisor.process_command(command)
    catch
      error ->
        Logger.error("RA mailbox communication error: #{inspect(error)}")
        {:error, "RA communication error: #{inspect(error)}"}
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
