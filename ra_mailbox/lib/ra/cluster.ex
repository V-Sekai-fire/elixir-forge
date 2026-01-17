defmodule RAMailbox.RA.Cluster do
  @moduledoc """
  RA Cluster manager for single RA node demonstration.

  For simplicity, this starts a single RA server instead of a full cluster.
  In production, you'd configure multiple RA servers for raft consensus.
  """

  use GenServer
  require Logger

  def start_link(ra_servers_config) do
    GenServer.start_link(__MODULE__, ra_servers_config, name: __MODULE__)
  end

  @impl true
  def init(ra_servers_config) do
    Logger.info("Starting RA Cluster Manager")

    # For demo, start just one RA server
    [first_server_config | _] = ra_servers_config

    case start_ra_server(first_server_config) do
      :ok ->
        {:ok, %{servers: ra_servers_config, started: [first_server_config]}}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  # Start a single RA server for demo
  def start_ra_server({ra_module, ra_name}) do
    # RA configuration
    ra_config = %{
      name: ra_name,
      uid: "mailbox_cluster",
      machine: {:module, ra_module, %{}},
      data_dir: 'priv/ra'
    }

    case :ra.start_server(ra_config) do
      {:ok, _} ->
        Logger.info("RA server #{inspect(ra_name)} started")
        :ok
      {:error, {:already_started, _}} ->
        Logger.info("RA server #{inspect(ra_name)} already running")
        :ok
      error ->
        Logger.error("Failed to start RA server: #{inspect(error)}")
        error
    end
  end

  @impl true
  def handle_call(:get_servers, _from, state) do
    {:reply, state.started, state}
  end

  @impl true
  def handle_call({:get_server, name}, _from, state) do
    case Enum.find(state.started, fn {_, s_name} -> s_name == name end) do
      {ra_module, ra_name} -> {:reply, {ra_module, ra_name}, state}
      nil -> {:reply, :not_found, state}
    end
  end

  # API functions
  def get_servers do
    GenServer.call(__MODULE__, :get_servers)
  end

  def get_server(name) do
    GenServer.call(__MODULE__, {:get_server, name})
  end
end
