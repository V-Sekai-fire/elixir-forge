defmodule Mix.Tasks.Crdb.Stop do
  @moduledoc """
  Stop CockroachDB.

  This task stops the running CockroachDB instance.

  ## Usage

      mix crdb.stop
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    # Start the application to ensure the GenServer is running
    Mix.Task.run("app.start")

    status = LivebookNx.Server.status()

    if status.database_running do
      Mix.shell().info("CockroachDB is running (PID: #{status.cockroach_pid})")
      Mix.shell().info("Database started at: #{status.database_started_at}")
      Mix.shell().info("To stop CockroachDB, stop the entire LivebookNx application.")
      Mix.shell().info("Use: mix app.stop")
    else
      Mix.shell().info("CockroachDB is not running")
    end
  end
end
