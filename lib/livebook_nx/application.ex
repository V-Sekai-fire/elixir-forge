defmodule LivebookNx.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start Ecto repo first
      LivebookNx.Repo,
      # Start Oban for job queuing
      {Oban, Application.fetch_env!(:livebook_nx, Oban)},
      # LivebookNx server for managing operations
      LivebookNx.Server
    ]

    opts = [strategy: :one_for_one, name: LivebookNx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
