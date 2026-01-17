defmodule ForgeClient.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # No supervised processes needed - CLI handles everything
    {:ok, self()}
  end
end
