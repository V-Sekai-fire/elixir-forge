defmodule LivebookNx.ZImage.Worker do
  @moduledoc """
  Oban worker for asynchronous Z-Image-Turbo image generation.
  """

  use Oban.Worker,
    queue: :zimage,
    max_attempts: 3,
    unique: [period: 300] # 5 minutes uniqueness

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"config" => config_params}}) do
    config = struct(LivebookNx.ZImage, config_params)

    Logger.info("Starting Z-Image generation job", %{
      job_id: inspect(self()),
      prompt: config.prompt,
      width: config.width,
      height: config.height
    })

    case LivebookNx.ZImage.generate(
           config.prompt,
           width: config.width,
           height: config.height,
           seed: config.seed,
           num_steps: config.num_steps,
           guidance_scale: config.guidance_scale,
           output_format: config.output_format
         ) do
      {:ok, output_path} ->
        Logger.info("Z-Image generation job completed", %{
          job_id: inspect(self()),
          output_path: output_path
        })
        {:ok, %{output_path: output_path}}

      {:error, reason} ->
        Logger.error("Z-Image generation job failed", %{
          job_id: inspect(self()),
          error: reason
        })
        {:error, reason}
    end
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff: 1m, 4m, 9m
    attempt * attempt * 60
  end
end
