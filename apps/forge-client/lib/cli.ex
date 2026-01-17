defmodule ForgeClient.CLI do
  @moduledoc """
  Command-line interface for Forge Client - Social VR Platform.
  """

  def main(args) do
    {opts, _args} = parse_options(args)

    cond do
      opts[:help] -> show_help_and_exit()
      opts[:dashboard] -> start_dashboard_and_exit()
      opts[:router] -> start_router_and_exit()
      true -> show_help_and_exit()
    end
  end

  defp parse_options(args) do
    OptionParser.parse(args,
      switches: [
        dashboard: :boolean,
        router: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :dashboard,
        r: :router,
        h: :help
      ]
    )
  end

  defp show_help_and_exit do
    show_help()
    System.halt(0)
  end

  defp start_dashboard_and_exit do
    ForgeClient.Dashboard.start()
    System.halt(0)
  end

  defp start_router_and_exit do
    start_router()
    System.halt(0)
  end

  defp start_router do
    IO.puts("Starting Zenoh router (zenohd)...")

    # Check if zenohd is available
    case check_zenohd_available() do
      :ok ->
        IO.puts("✓ Found zenohd binary")
        start_zenohd_process()

      :not_found ->
        show_zenohd_install_instructions()
        System.halt(1)
    end
  end

  defp check_zenohd_available do
    case System.cmd("which", ["zenohd"]) do
      {_, 0} -> :ok
      _ -> :not_found
    end
  end

  defp start_zenohd_process do
    IO.puts("Starting zenohd on localhost:7447...")

    # Start zenohd as a subprocess
    # Note: This will run in the foreground, blocking this Elixir process
    # User can Ctrl+C to stop it
    case System.cmd("zenohd", [], into: IO.stream(:stdio, :write)) do
      {_, 0} ->
        IO.puts("Zenoh router stopped gracefully")

      {error_output, code} ->
        IO.puts("Zenoh router exited with code #{code}: #{error_output}")
        System.halt(1)
    end
  end

  defp show_zenohd_install_instructions do
    IO.puts("""
    ✗ zenohd not found in PATH.

    Install zenohd to provide the Zenoh router:
    1. Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    2. Install Zenoh: cargo install zenohd
    3. Or see: https://zenoh.io/download/

    Zenoh router is required for P2P communication in the social VR platform.
    """)
  end

  defp show_help do
    IO.puts("""
    Forge Client - Social VR Platform

    USAGE:
      forge_client --dashboard    # Monitor active VR services
      forge_client --router       # Start Zenoh router for P2P networking
      forge_client --help         # Show this help

    EXAMPLES:
      forge_client --dashboard    # Monitor VR services
      forge_client --router       # Start networking
    """)
  end
end
