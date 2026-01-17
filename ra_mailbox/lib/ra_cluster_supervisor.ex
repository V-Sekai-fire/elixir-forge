defmodule RAMailbox.RAClusterSupervisor do
  @moduledoc """
  Supervisor for RA (Raft) cluster with mailbox server.

  This supervisor:
  1. Starts a single RA server for development (expandable for production)
  2. Handles RA server lifecycle
  3. Provides access to RA server operations
  """

  use GenServer
  require Logger

  @ra_server_name :mailbox_ra
  @ra_server_module RAMailbox.RAServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting RA Cluster Supervisor")

    # Start RA server
    case start_ra_server() do
      {:ok, ra_name} ->
        Logger.info("RA server started successfully: #{inspect(ra_name)}")
        {:ok, %{ra_server: ra_name}}

      {:error, reason} ->
        Logger.error("Failed to start RA server: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("Stopping RA Cluster Supervisor")
    # RA handles its own shutdown
  end

  # Public API
  def put(user_id, message) do
    GenServer.call(@ra_server_module, {:put, @ra_server_name, user_id, message})
  rescue
    _ -> {:error, :put_failed}
  end

  def consume(user_id) do
    GenServer.call(@ra_server_module, {:consume, @ra_server_name, user_id})
  rescue
    _ -> {:error, :consume_failed}
  end

  def peek(user_id) do
    GenServer.call(@ra_server_module, {:peek, @ra_server_name, user_id})
  rescue
    _ -> {:error, :peek_failed}
  end

  def get_message_count(user_id) do
    GenServer.call(@ra_server_module, {:get_count, @ra_server_name, user_id})
  rescue
    _ -> 0
  end

  # Process commands for Zenoh bridge compatibility
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

  # Private functions
  defp start_ra_server do
    # Use the RA server's built-in start_simple function
    @ra_server_module.start_simple()
  end
end
