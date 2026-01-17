defmodule RAMailbox.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # RA cluster configuration
    ra_servers = [
      {RAMailbox.RA.MailboxRA, :mailbox_1@localhost},
      {RAMailbox.RA.MailboxRA, :mailbox_2@localhost},
      {RAMailbox.RA.MailboxRA, :mailbox_3@localhost}
    ]

    children = [
      # Start RA cluster using RA Server
      %{
        id: RAMailbox.RA.Cluster,
        start: {RAMailbox.RA.Cluster, :start_link, [ra_servers]}
      },
      # Start Zenoh-RA bridge
      %{
        id: RAMailbox.ZenohBridge,
        start: {RAMailbox.ZenohBridge, :start_link, [ra_servers]}
      }
    ]

    opts = [strategy: :one_for_one, name: RAMailbox.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
