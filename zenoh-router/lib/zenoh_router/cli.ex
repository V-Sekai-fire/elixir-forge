defmodule ZenohRouter.CLI do
  @moduledoc """
  Command-line interface for ZenohRouter.

  Provides management commands for zenohd (Zenoh router daemon).
  """

  def main(args) do
    {opts, args, _} = OptionParser.parse(args,
      switches: [
        port: :integer,
        config: :string,
        foreground: :boolean,
        help: :boolean
      ],
      aliases: [
        p: :port,
        c: :config,
        f: :foreground,
        h: :help
      ]
    )

    if Keyword.get(opts, :help, false) do
      show_help()
      System.halt(0)
    end

    command = List.first(args) || "start"
    case command do
      "start" -> start_router(opts)
      "stop" -> stop_router(opts)
      "status" -> show_status(opts)
      "logs" -> show_logs(opts)
      other ->
        IO.puts("Unknown command: #{other}")
        show_help()
        System.halt(1)
    end
  end

  defp start_router(opts) do
    IO.puts("Starting Zenoh router...")

    # Check if zenohd is available
    with {0, _} <- System.cmd("which", ["zenohd"]),
         IO.puts("✓ Found zenohd binary") do

      port = Keyword.get(opts, :port, 7447)
      config_file = Keyword.get(opts, :config)
      foreground = Keyword.get(opts, :foreground, false)

      IO.puts("Starting zenohd on localhost:#{port}...")

      # Build arguments
      args = ["--ws"]  # Enable WebSocket
      if config_file do
        args = ["--config", config_file | args]
      else
        args = ["--listen", "tcp/[::]:#{port}", "--rest-api"] ++ args
      end

      if foreground do
        # Run in foreground - blocks process
        case System.cmd("zenohd", args, into: IO.stream(:stdio, :write)) do
          {output, 0} ->
            IO.puts("\nZenoh router stopped gracefully")
          {error_output, code} ->
            IO.puts("Zenoh router exited with code #{code}: #{error_output}")
            System.halt(1)
        end
      else
        # Run in background
        try do
          {:ok, pid} = Task.start(fn ->
            System.cmd("zenohd", args ++ ["--admin-space", "^zenohd/**"],
                        into: IO.stream(:stdio, :line))
          end)
          IO.puts("✓ Zenoh router started in background (PID: #{inspect(pid.pid)})")
          IO.puts("  REST API: http://localhost:#{port}/@config")
          IO.puts("  Admin space: zenohd/**")
          IO.puts("")
          IO.puts("Press Ctrl+C to stop the router")
          Process.sleep(:infinity)  # Blocks to keep alive
        rescue
          e ->
            IO.puts("Failed to start router: #{inspect(e)}")
            System.halt(1)
        end
      end
    else
      {_code, _} ->
        IO.puts("""
        ✗ zenohd not found in PATH.

        Zenoh router daemon (zenohd) must be installed to manage Zenoh networks.
        Install options:

        1. Using Cargo (Rust):
           cargo install zenohd

        2. ⚰️ DEPRECATED: macOS Homebrew method broken (2026-01-16)
           # brew tap eclipse-zenoh/zenoh
           # brew install zenohd

        3. Pre-built binaries:
           See: https://zenoh.io/download/

        Zenoh router is required for P2P communication between Forge AI services.
        """)
        System.halt(1)
    end
  end

  defp stop_router(_opts) do
    IO.puts("Stopping Zenoh router...")

    # Try to find and stop zenohd processes
    case System.cmd("pkill", ["-f", "zenohd"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✓ Zenoh router stopped")
      {_output, _code} ->
        IO.puts("No running zenohd processes found")
    end
  end

  defp show_status(_opts) do
    IO.puts("Checking Zenoh router status...")

    # Check if zenohd is running
    case System.cmd("pgrep", ["-f", "zenohd"], stderr_to_stdout: true) do
      {pids, 0} when pids != "" ->
        pids = String.trim(pids) |> String.split("\n") |> length()
        IO.puts("✓ Zenoh router is running (#{pids} process#{if pids > 1, do: "es"})")

        # Try to check router status via REST API
        case :httpc.request(:get, {'http://localhost:7447/@config/rest/status', []}, [], []) do
          {:ok, {{_version, 200, _reason}, _headers, body}} ->
            case Jason.decode(body) do
              {:ok, %{"plugins" => plugins, "session" => session} = status} ->
                IO.puts("  REST API available")
                IO.puts("  Plugins: #{Map.keys(plugins) |> Enum.join(", ")}")
                IO.puts("  Session: #{inspect(session, pretty: true)}")
                IO.puts("  Router open: http://localhost:7447/")
              _ ->
                IO.puts("  REST API available")
            end
          _ ->
            IO.puts("  Router running, but REST API not accessible")
        end

      _ ->
        IO.puts("✗ No Zenoh router found running")
        IO.puts("Run 'zenoh_router start' to launch the router")
    end
  end

  defp show_logs(_opts) do
    IO.puts("Showing Zenoh router logs...")
    IO.puts("Tail logs (press Ctrl+C to stop):")

    # Try to tail logs - this is a placeholder as zenohd might log differently
    case System.cmd("tail", ["-f", "/tmp/zenohd.log"], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok
      _ ->
        IO.puts("No log file found at /tmp/zenohd.log")
        IO.puts("Router logs may be available via 'journalctl -u zenohd' if running as service")
    end
  end

  defp show_help do
    IO.puts("""
    ZenohRouter - Manage Zenoh router daemon for Forge AI platform

    USAGE:
      zenoh_router COMMAND [options]

    COMMANDS:
      start     Start the Zenoh router daemon (default command)
      stop      Stop running Zenoh router processes
      status    Show router status and connection info
      logs      Show router logs (if available)

    OPTIONS:
      -p, --port PORT          Port for router to listen on (default: 7447)
      -c, --config FILE        Path to zenohd config file
      -f, --foreground         Run router in foreground (blocking)
      -h, --help               Show this help

    CONFIGURATION:
      The router automatically enables:
      - TCP listener on ::PORT
      - REST API for monitoring at http://localhost:PORT/@config
      - Admin space at zenohd/**

    EXAMPLES:
      zenoh_router start                    # Start router on port 7447
      zenoh_router start -p 8080            # Start on custom port
      zenoh_router start --config router.yaml # Use custom config
      zenoh_router status                   # Check if running
      zenoh_router stop                     # Stop router
      zenoh_router logs                     # View logs

    Zenoh router enables P2P communication for distributed AI services
    in the Forge platform.

    INSTALLATION:
      1. cargo install zenohd
      2. ⚰️ DEPRECATED: homebrew method broken (2026-01-16)
         # brew tap eclipse-zenoh/zenoh
         # brew install zenohd
      3. Download pre-built: https://zenoh.io/download/
    """)
  end
end
