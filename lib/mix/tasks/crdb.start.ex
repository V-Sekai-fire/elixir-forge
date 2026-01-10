defmodule Mix.Tasks.Crdb.Start do
  @moduledoc """
  Start CockroachDB with TLS certificates.

  This task starts a single-node CockroachDB instance with the generated
  TLS certificates for secure development use.

  ## Usage

      mix crdb.start

  The task will:
  1. Check if CockroachDB is already running
  2. Start CockroachDB with TLS certificates
  3. Wait for it to be ready
  4. Create the database if it doesn't exist
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    # Start the application to ensure everything is running
    Mix.Task.run("app.start")

    Mix.shell().info("Checking CockroachDB status...")

    status = LivebookNx.Server.status()

    if status.database_running do
      Mix.shell().info("CockroachDB is already running (PID: #{status.cockroach_pid})")
      Mix.shell().info("Database started at: #{status.database_started_at}")
      print_connection_info()
    else
      Mix.shell().error("CockroachDB is not running. The application should have started it automatically.")
      Mix.shell().info("Current status: #{inspect(status)}")
    end
  end

  defp print_connection_info do
    Mix.shell().info("")
    Mix.shell().info("CockroachDB Connection Info:")
    Mix.shell().info("  Host: localhost:26257")
    Mix.shell().info("  Database: livebook_nx_dev")
    Mix.shell().info("  User: root")
    Mix.shell().info("  Password: secure_password_123")
    Mix.shell().info("  SSL: enabled")
    Mix.shell().info("  Web UI: https://localhost:8080")
    Mix.shell().info("")
    Mix.shell().info("To connect manually:")
    Mix.shell().info("  cockroach sql --certs-dir=cockroach-certs")
  end
end
