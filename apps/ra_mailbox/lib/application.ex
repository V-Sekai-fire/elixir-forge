defmodule RAMailbox.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start RA cluster supervisor (distributed mailbox state)
      %{
        id: RAMailbox.RAClusterSupervisor,
        start: {RAMailbox.RAClusterSupervisor, :start_link, []}
      },
      # Start Zenoh-RA bridge (JSON over Zenoh networking)
      %{
        id: RAMailbox.ZenohBridge,
        start: {RAMailbox.ZenohBridge, :start_link, []}
      }
    ]

    opts = [strategy: :one_for_one, name: RAMailbox.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
