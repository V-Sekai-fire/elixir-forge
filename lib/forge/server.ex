defmodule Forge.Server do
  @moduledoc """
  GenServer for managing Forge AI inference operations.
  """

  use GenServer
  require Logger

  alias Forge.{Qwen3VL, ZImage}

  # Client API

  @doc """
  Starts the Forge server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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
  def init(_opts) do
    Logger.info("Starting Forge.Server")

    state = %{
      jobs_completed: 0,
      jobs_failed: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:run_qwen3vl, image_path, opts}, _from, state) do
    Logger.info("Running Qwen3-VL inference", %{image_path: image_path})

    config = Forge.Qwen3VL.new([
      image_path: image_path,
      prompt: opts[:prompt],
      max_tokens: opts[:max_tokens],
      temperature: opts[:temperature],
      top_p: opts[:top_p],
      output_path: opts[:output_path],
      use_flash_attention: opts[:use_flash_attention],
      use_4bit: opts[:use_4bit]
    ])

    result = Forge.Qwen3VL.run(config)
    new_state = update_job_stats(state, result)

    Logger.info("Qwen3-VL inference completed", %{result: inspect(result)})
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:run_zimage, prompt, opts}, _from, state) do
    Logger.info("Running Z-Image generation", %{prompt: prompt})

    result = ZImage.generate(prompt, opts)
    new_state = update_job_stats(state, result)

    Logger.info("Z-Image generation completed", %{result: inspect(result)})
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:run_qwen3vl, image_path, opts}, _from, state) do
    Logger.info("Running Qwen3-VL inference", %{image_path: image_path})

    result = Qwen3VL.infer(image_path, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:run_zimage, prompt, opts}, _from, state) do
    Logger.info("Running Z-Image generation", %{prompt: prompt})

    result = ZImage.generate(prompt, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      jobs_completed: state.jobs_completed,
      jobs_failed: state.jobs_failed
    }

    {:reply, status, state}
  end

  # Private Functions

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
end
