defmodule LivebookNx.Server do
  @moduledoc """
  GenServer for managing LivebookNx operations including database lifecycle,
  AI inference, and background job processing.
  """

  use GenServer
  require Logger

  alias LivebookNx.{Qwen3VL, ZImage}

  # Client API

  @doc """
  Starts the LivebookNx server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts CockroachDB with TLS certificates.
  """
  def start_database do
    GenServer.call(__MODULE__, :start_database)
  end

  @doc """
  Stops the running CockroachDB instance.
  """
  def stop_database do
    GenServer.call(__MODULE__, :stop_database)
  end

  @doc """
  Checks if CockroachDB is currently running.
  """
  def database_running? do
    GenServer.call(__MODULE__, :database_running?)
  end

  @doc """
  Runs Qwen3-VL inference on an image.
  """
  def run_qwen3vl_inference(image_path, opts \\ []) do
    GenServer.call(__MODULE__, {:run_qwen3vl, image_path, opts})
  end

  @doc """
  Runs Z-Image-Turbo image generation.
  """
  def run_zimage_generation(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:run_zimage, prompt, opts})
  end

  @doc """
  Queues Qwen3-VL inference for asynchronous processing.
  """
  def queue_qwen3vl_inference(image_path, opts \\ []) do
    GenServer.call(__MODULE__, {:queue_qwen3vl, image_path, opts})
  end

  @doc """
  Queues Z-Image-Turbo generation for asynchronous processing.
  """
  def queue_zimage_generation(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:queue_zimage, prompt, opts})
  end

  @doc """
  Gets the current server status.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.info("Starting LivebookNx.Server")

    state = %{
      cockroach_pid: nil,
      cockroach_port: Keyword.get(opts, :cockroach_port, 26_257),
      database_started_at: nil,
      jobs_completed: 0,
      jobs_failed: 0
    }

    # Start the database automatically on server startup
    case do_start_database(state) do
      {:ok, pid, new_state} ->
        Logger.info("Database started successfully during server initialization", %{pid: pid})
        {:ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to start database during server initialization", %{reason: reason})
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:start_database, _from, state) do
    case do_start_database(state) do
      {:ok, pid, new_state} ->
        Logger.info("CockroachDB started successfully", %{pid: pid})
        {:reply, {:ok, pid}, new_state}

      {:error, reason} ->
        Logger.error("Failed to start CockroachDB", %{error: reason})
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:stop_database, _from, state) do
    case do_stop_database(state) do
      {:ok, new_state} ->
        Logger.info("CockroachDB stopped successfully")
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to stop CockroachDB", %{error: reason})
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:database_running?, _from, state) do
    running? = state.cockroach_pid != nil and Process.alive?(state.cockroach_pid)
    {:reply, running?, state}
  end

  @impl true
  def handle_call({:run_qwen3vl, image_path, opts}, _from, state) do
    config = LivebookNx.Qwen3VL.new([
      image_path: image_path,
      prompt: opts[:prompt],
      max_tokens: opts[:max_tokens],
      temperature: opts[:temperature],
      top_p: opts[:top_p],
      output_path: opts[:output_path],
      use_flash_attention: opts[:use_flash_attention],
      use_4bit: opts[:use_4bit]
    ])

    result = LivebookNx.Qwen3VL.run(config)
    new_state = update_job_stats(state, result)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:run_zimage, prompt, opts}, _from, state) do
    result = ZImage.generate(prompt, opts)
    new_state = update_job_stats(state, result)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:queue_qwen3vl, image_path, opts}, _from, state) do
    result = Qwen3VL.queue_inference(image_path, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:queue_zimage, prompt, opts}, _from, state) do
    result = ZImage.queue_generation(prompt, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      database_running: state.cockroach_pid != nil and Process.alive?(state.cockroach_pid),
      cockroach_pid: state.cockroach_pid,
      database_started_at: state.database_started_at,
      jobs_completed: state.jobs_completed,
      jobs_failed: state.jobs_failed,
      uptime: uptime(state)
    }

    {:reply, status, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("LivebookNx.Server terminating", %{reason: reason})

    # Clean up database if running
    if state.cockroach_pid do
      do_stop_database(state)
    end
  end

  # Private Functions

  defp do_start_database(state) do
    with :ok <- check_database_not_running(state),
         :ok <- check_certificates_exist(),
         :ok <- check_cockroach_binary_exists(),
         {:ok, output} <- start_cockroach_process(),
         {:ok, pid} <- find_cockroach_pid(),
         new_state <- update_state_with_pid(state, pid),
         :ok <- create_database() do
      Logger.info("Database created successfully")
      {:ok, pid, new_state}
    else
      {:error, reason} ->
        Logger.error("Database startup failed", %{reason: reason})
        {:error, reason}
    end
  end

  # Check if database is not already running
  defp check_database_not_running(state) do
    if state.cockroach_pid && Process.alive?(state.cockroach_pid) do
      {:error, "CockroachDB is already running"}
    else
      :ok
    end
  end

  # Check if TLS certificates exist
  defp check_certificates_exist do
    cert_files = ["cockroach-certs/ca.crt", "cockroach-certs/node.crt", "cockroach-certs/node.key"]

    if Enum.all?(cert_files, &File.exists?/1) do
      :ok
    else
      {:error, "TLS certificates not found. Run certificate generation first."}
    end
  end

  # Check if CockroachDB binary exists
  defp check_cockroach_binary_exists do
    cockroach_path = "tools/cockroach-v22.1.22.windows-6.2-amd64/cockroach.exe"

    if File.exists?(cockroach_path) do
      :ok
    else
      {:error, "CockroachDB binary not found at #{cockroach_path}"}
    end
  end

  # Start the CockroachDB process
  defp start_cockroach_process do
    cockroach_path = "tools/cockroach-v22.1.22.windows-6.2-amd64/cockroach.exe"
    data_dir = "cockroach-data"
    certs_dir = "cockroach-certs"

    args = [
      "start-single-node",
      "--store=path=#{data_dir}",
      "--certs-dir=#{certs_dir}"
    ]

    case System.cmd(cockroach_path, args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("CockroachDB started", %{output: output})
        # Wait a moment for startup
        Process.sleep(3000)
        {:ok, output}
      {error_output, exit_code} ->
        {:error, "Failed to start CockroachDB (exit code #{exit_code}): #{error_output}"}
    end
  end

  # Update state with the new PID and start time
  defp update_state_with_pid(state, pid) do
    %{state |
      cockroach_pid: pid,
      database_started_at: DateTime.utc_now()
    }
  end

  defp do_stop_database(state) do
    if state.cockroach_pid do
      perform_graceful_shutdown(state)
    else
      {:error, "CockroachDB is not running"}
    end
  end

  defp perform_graceful_shutdown(state) do
    cockroach_path = "tools/cockroach-v22.1.22.windows-6.2-amd64/cockroach.exe"

    # Try graceful shutdown first
    case System.cmd(cockroach_path, ["quit", "--certs-dir=cockroach-certs"], []) do
      {_output, 0} ->
        # Wait for process to exit
        Process.sleep(2000)

        if Process.alive?(state.cockroach_pid) do
          # Force kill if still running
          System.cmd("taskkill", ["/PID", "#{state.cockroach_pid}", "/F"], [])
          Process.sleep(1000)
        end

        new_state = %{state |
          cockroach_pid: nil,
          database_started_at: nil
        }
        {:ok, new_state}

      {error_output, _exit_code} ->
        {:error, "Failed to stop CockroachDB gracefully: #{error_output}"}
    end
  end

  defp find_cockroach_pid do
    case run_tasklist_command() do
      {:ok, output} ->
        parse_tasklist_output(output)
      {:error, error, code} ->
        Logger.error("Tasklist command failed", %{error: error, code: code})
        :error
    end
  end

  # Run the tasklist command to get process information
  defp run_tasklist_command do
    case System.cmd("tasklist", ["/FI", "IMAGENAME eq cockroach.exe", "/FO", "CSV"], []) do
      {output, 0} ->
        Logger.info("Tasklist output", %{output: output})
        {:ok, output}
      {error, code} ->
        {:error, error, code}
    end
  end

  # Parse the tasklist CSV output to find the PID
  defp parse_tasklist_output(output) do
    lines = String.split(output, "\n")
    # Skip header line and find the data line
    case Enum.find(lines, &String.contains?(&1, "cockroach.exe")) do
      nil ->
        Logger.error("No cockroach.exe found in tasklist")
        :error
      line ->
        parse_csv_line(line)
    end
  end

  # Parse a single CSV line to extract the PID
  defp parse_csv_line(line) do
    Logger.info("Found cockroach line", %{line: line})
    # CSV format: "Image Name","PID","Session Name","Session#","Mem Usage"
    # Example: "cockroach.exe","11368","Console","1","274,020 K"
    case String.split(line, ",") do
      [_image, pid_str | _] ->
        parse_pid_string(pid_str)
      _ ->
        Logger.error("Unexpected CSV format", %{line: line})
        :error
    end
  end

  # Parse the PID string and convert to integer
  defp parse_pid_string(pid_str) do
    # Remove quotes from PID
    pid_clean = String.trim(pid_str, "\"")
    Logger.info("Parsed PID string", %{pid_str: pid_clean})

    case Integer.parse(pid_clean) do
      {pid, _} ->
        Logger.info("Successfully parsed PID", %{pid: pid})
        {:ok, pid}
      :error ->
        Logger.error("Failed to parse PID", %{pid_str: pid_clean})
        :error
    end
  end

  defp update_job_stats(state, result) do
    case result do
      {:ok, _} ->
        %{state | jobs_completed: state.jobs_completed + 1}

      {:error, _} ->
        %{state | jobs_failed: state.jobs_failed + 1}

      _ ->
        state
    end
  end

  defp create_database do
    cockroach_path = "tools/cockroach-v22.1.22.windows-6.2-amd64/cockroach.exe"
    sql = "CREATE DATABASE IF NOT EXISTS livebook_nx_dev;"

    case System.cmd(cockroach_path, ["sql", "--certs-dir=cockroach-certs", "--execute=#{sql}"], stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("Database 'livebook_nx_dev' created successfully")
        :ok

      {error_output, exit_code} ->
        Logger.error("Failed to create database", %{exit_code: exit_code, error: error_output})
        {:error, "Exit code #{exit_code}: #{error_output}"}
    end
  end

  defp uptime(state) do
    case state.database_started_at do
      nil ->
        0

      started_at ->
        DateTime.diff(DateTime.utc_now(), started_at, :second)
    end
  end
end
