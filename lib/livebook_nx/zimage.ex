defmodule LivebookNx.ZImage do
  @moduledoc """
  Z-Image-Turbo image generation module.

  This module provides high-performance image generation using the Z-Image-Turbo model
  from Tongyi-MAI. It supports photorealistic image generation from text prompts with
  configurable parameters for quality, size, and style control.
  """

  require Logger

  @model_id "Tongyi-MAI/Z-Image-Turbo"
  @weights_dir "pretrained_weights/Z-Image-Turbo"

  @doc """
  Configuration struct for image generation.
  """
  defstruct [
    :prompt,
    :width,
    :height,
    :seed,
    :num_steps,
    :guidance_scale,
    :output_format
  ]

  @type t :: %__MODULE__{
    prompt: String.t(),
    width: pos_integer(),
    height: pos_integer(),
    seed: non_neg_integer(),
    num_steps: pos_integer(),
    guidance_scale: float(),
    output_format: String.t()
  }

  @doc """
  Generates an image from a text prompt.

  ## Parameters

    - `prompt`: Text description of the image to generate
    - `opts`: Keyword list of options

  ## Options

    - `:width` - Image width in pixels (64-2048, default: 1024)
    - `:height` - Image height in pixels (64-2048, default: 1024)
    - `:seed` - Random seed (0 for random, default: 0)
    - `:num_steps` - Number of inference steps (default: 4)
    - `:guidance_scale` - Guidance scale (default: 0.0)
    - `:output_format` - Output format: "png", "jpg", "jpeg" (default: "png")

  ## Examples

      iex> LivebookNx.ZImage.generate("a beautiful sunset over mountains")
      {:ok, "output/20260109_21_39_19/zimage_20260109_21_39_19.png"}

      iex> LivebookNx.ZImage.generate("a cat wearing a hat", width: 512, height: 512, seed: 42)
      {:ok, "output/20260109_21_39_19/zimage_20260109_21_39_19.png"}
  """
  @spec generate(String.t(), keyword()) :: {:ok, Path.t()} | {:error, term()}
  def generate(prompt, opts \\ []) do
    config = %__MODULE__{
      prompt: prompt,
      width: Keyword.get(opts, :width, 1024),
      height: Keyword.get(opts, :height, 1024),
      seed: Keyword.get(opts, :seed, 0),
      num_steps: Keyword.get(opts, :num_steps, 4),
      guidance_scale: Keyword.get(opts, :guidance_scale, 0.0),
      output_format: Keyword.get(opts, :output_format, "png")
    }

    case validate_config(config) do
      :ok ->
        do_generate(config)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates multiple images from a list of prompts.

  ## Examples

      iex> LivebookNx.ZImage.generate_batch(["cat", "dog", "bird"], width: 512)
      {:ok, ["output/.../zimage_1.png", "output/.../zimage_2.png", "output/.../zimage_3.png"]}
  """
  @spec generate_batch([String.t()], keyword()) :: {:ok, [Path.t()]} | {:error, term()}
  def generate_batch(prompts, opts \\ []) do
    results = Enum.map(prompts, fn prompt ->
      generate(prompt, opts)
    end)

    successful = Enum.filter(results, fn
      {:ok, _} -> true
      _ -> false
    end)

    if length(successful) == length(prompts) do
      {:ok, Enum.map(results, fn {:ok, path} -> path end)}
    else
      failed = Enum.filter(results, fn
        {:error, _} -> true
        _ -> false
      end)
      {:error, "Batch generation failed: #{length(successful)}/#{length(prompts)} succeeded, #{length(failed)} failed"}
    end
  end

  @doc """
  Queues an image generation job for asynchronous processing.

  ## Examples

      iex> LivebookNx.ZImage.queue_generation("a beautiful landscape")
      {:ok, %Oban.Job{}}
  """
  @spec queue_generation(String.t(), keyword()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def queue_generation(prompt, opts \\ []) do
    config = %{
      prompt: prompt,
      width: Keyword.get(opts, :width, 1024),
      height: Keyword.get(opts, :height, 1024),
      seed: Keyword.get(opts, :seed, 0),
      num_steps: Keyword.get(opts, :num_steps, 4),
      guidance_scale: Keyword.get(opts, :guidance_scale, 0.0),
      output_format: Keyword.get(opts, :output_format, "png")
    }

    case validate_config(struct(__MODULE__, config)) do
      :ok ->
        %{config: config}
        |> LivebookNx.ZImage.Worker.new()
        |> Oban.insert()
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp validate_config(%__MODULE__{} = config) do
    cond do
      String.trim(config.prompt) == "" ->
        {:error, "Prompt cannot be empty"}

      config.width < 64 or config.width > 2048 ->
        {:error, "Width must be between 64 and 2048 pixels"}

      config.height < 64 or config.height > 2048 ->
        {:error, "Height must be between 64 and 2048 pixels"}

      config.num_steps < 1 ->
        {:error, "Number of steps must be at least 1"}

      config.guidance_scale < 0.0 ->
        {:error, "Guidance scale must be non-negative"}

      config.output_format not in ["png", "jpg", "jpeg"] ->
        {:error, "Output format must be png, jpg, or jpeg"}

      true ->
        :ok
    end
  end

  defp do_generate(%__MODULE__{} = config) do
    # Create output directory
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H_%M_%S")
    output_dir = Path.join(["output", timestamp])
    File.mkdir_p!(output_dir)

    # Generate unique filename
    filename = "zimage_#{timestamp}.#{config.output_format}"
    output_path = Path.join(output_dir, filename)

    Logger.info("Starting Z-Image-Turbo generation", %{
      prompt: config.prompt,
      width: config.width,
      height: config.height,
      seed: config.seed,
      num_steps: config.num_steps
    })

    case run_python_generation(config, output_path) do
      :ok ->
        Logger.info("Z-Image-Turbo generation completed", %{output_path: output_path})
        {:ok, output_path}

      {:error, reason} ->
        Logger.error("Z-Image-Turbo generation failed", %{error: reason})
        {:error, reason}
    end
  end

  defp run_python_generation(config, output_path) do
    python_code = """
import json
import os
import sys
import logging
from pathlib import Path
from PIL import Image
import torch
from diffusers import DiffusionPipeline

# Suppress verbose logging
logging.getLogger("huggingface_hub").setLevel(logging.ERROR)
logging.getLogger("transformers").setLevel(logging.ERROR)
logging.getLogger("diffusers").setLevel(logging.ERROR)
os.environ["TRANSFORMERS_VERBOSITY"] = "error"
os.environ["HF_HUB_DISABLE_PROGRESS_BARS"] = "1"

# Disable tqdm progress bars
try:
    from tqdm import tqdm
    original_init = tqdm.__init__
    def silent_init(self, *args, **kwargs):
        kwargs['disable'] = True
        return original_init(self, *args, **kwargs)
    tqdm.__init__ = silent_init
except ImportError:
    pass

# Performance optimizations
cpu_count = os.cpu_count() or 1
half_cpu_count = max(1, cpu_count // 2)
os.environ["MKL_NUM_THREADS"] = str(half_cpu_count)
os.environ["OMP_NUM_THREADS"] = str(half_cpu_count)
torch.set_num_threads(half_cpu_count)

if torch.cuda.is_available():
    torch.set_float32_matmul_precision("high")
    device = "cuda"
    dtype = torch.bfloat16
else:
    device = "cpu"
    dtype = torch.float32

MODEL_ID = "#{@model_id}"
weights_dir = "#{@weights_dir}"

# Load pipeline
if os.path.exists(weights_dir) and os.path.exists(os.path.join(weights_dir, "config.json")):
    print(f"Loading from local directory: {weights_dir}")
    pipe = DiffusionPipeline.from_pretrained(
        weights_dir,
        torch_dtype=dtype,
        trust_remote_code=True
    )
else:
    print(f"Loading from Hugging Face Hub: {MODEL_ID}")
    pipe = DiffusionPipeline.from_pretrained(
        MODEL_ID,
        torch_dtype=dtype,
        trust_remote_code=True
    )

pipe = pipe.to(device)

# Set seed
generator = None
if #{if config.seed > 0, do: "True", else: "False"}:
    generator = torch.Generator(device=device).manual_seed(#{config.seed})

# Generate image
with torch.no_grad():
    result = pipe(
        "#{String.replace(config.prompt, "\"", "\\\"")}",
        width=#{config.width},
        height=#{config.height},
        num_inference_steps=#{config.num_steps},
        guidance_scale=#{config.guidance_scale},
        generator=generator
    )

# Save image
image = result.images[0]
image.save("#{String.replace(output_path, "\\", "/")}", "#{config.output_format}")

print("Image generated successfully")
"""

    try do
      Pythonx.eval(python_code)
      :ok
    rescue
      e in Pythonx.Error ->
        {:error, "Python execution failed: #{inspect(e)}"}
    end
  end
end
