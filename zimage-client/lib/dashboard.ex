defmodule ZimageClient.Dashboard do
  @moduledoc """
  Service Dashboard for monitoring active Zenoh liveliness tokens in the Forge fabric.
  """

  def start() do
    run_dashboard()
  end

  defp run_dashboard() do
    IO.puts("Forge Service Dashboard")
    IO.puts("========================")
    IO.puts("Active AI Services:")
    IO.puts("")

    # Start the session and monitoring
    {:ok, session} = Zenohex.open()

    # Subscribe to liveliness queries under "forge/services/**"
    liveliness_subscriber = Zenohex.Session.declare_subscriber(session, "forge/services/**", liveliness: true)

    # Listen for changes
    loop(liveliness_subscriber)
  end

  defp loop(subscriber) do
    Zenohex.Subscriber.loop(subscriber, fn sample ->
      case sample.kind do
        :put ->
          IO.puts("[+] #{sample.key_expr}")
        :delete ->
          IO.puts("[-] #{sample.key_expr}")
      end
    end)
  end
end
