defmodule ForgeClient.Dashboard do
  @moduledoc """
  Service Dashboard for monitoring active Zenoh liveliness tokens in the Forge VR platform.
  """

  use GenServer

  def start do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    IO.puts("Forge VR Service Dashboard")
    IO.puts("==========================")
    IO.puts("Active VR Services:")
    IO.puts("")

    # Start the session and monitoring
    {:ok, session_id} = Zenohex.Session.open()

    # Subscribe to liveliness queries under "forge/services/**"
    {:ok, subscriber_id} = Zenohex.Session.declare_subscriber(session_id, "forge/services/**", self())

    {:ok, %{session_id: session_id, subscriber_id: subscriber_id}}
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    case sample.kind do
      :put ->
        IO.puts("[+] #{sample.key_expr}")

      :delete ->
        IO.puts("[-] #{sample.key_expr}")
    end
    {:noreply, state}
  end

  def terminate(_reason, %{session_id: session_id, subscriber_id: subscriber_id}) do
    Zenohex.Subscriber.undeclare(subscriber_id)
    Zenohex.Session.close(session_id)
  end
end
