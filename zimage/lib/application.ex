defmodule Zimage.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Zimage.Worker.start_link(arg)
      # {Zimage.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Zimage.Supervisor]
    Supervisor.start_link(children, opts)
  end
end