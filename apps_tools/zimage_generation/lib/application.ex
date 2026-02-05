defmodule ZImageGeneration.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # No children needed - pipelines are started directly
    Supervisor.start_link([], [strategy: :one_for_one, name: ZImageGeneration.Supervisor])
  end
end