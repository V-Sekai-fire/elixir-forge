defmodule ForgeClient.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ForgeClient.Client, []}
    ]

    opts = [strategy: :one_for_one, name: ForgeClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
