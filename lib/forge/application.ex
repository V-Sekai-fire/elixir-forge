defmodule Forge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Forge server for managing operations
      Forge.Server
    ]

    opts = [strategy: :one_for_one, name: Forge.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
