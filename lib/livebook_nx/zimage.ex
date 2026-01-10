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
    validations = [
      {String.trim(config.prompt) == "", "Prompt cannot be empty"},
      {config.width < 64 or config.width > 2048, "Width must be between 64 and 2048 pixels"},
      {config.height < 64 or config.height > 2048, "Height must be between 64 and 2048 pixels"},
      {config.num_steps < 1, "Number of steps must be at least 1"},
      {config.guidance_scale < 0.0, "Guidance scale must be non-negative"},
      {config.output_format not in ["png", "jpg", "jpeg"], "Output format must be png, jpg, or jpeg"}
    ]

    case Enum.find(validations, fn {condition, _} -> condition end) do
      {true, message} -> {:error, message}
      nil -> :ok
    end
  end

  defp do_generate(%__MODULE__{} = config) do
    # Validate and sanitize inputs for security
    with {:ok, safe_prompt} <- {:ok, LivebookNx.Security.sanitize_prompt(config.prompt)},
         {:ok, output_path} <- create_secure_output_path(config.output_format) do

      # Initialize Python environment if not already initialized
      unless Process.whereis(Pythonx.Supervisor) do
        pyproject_path = Path.join(["config", "qwen_pyproject.toml"])
        pyproject_content = File.read!(pyproject_path)
        Pythonx.uv_init(pyproject_content)
      end

      Logger.info("Starting Z-Image-Turbo generation", %{
        prompt: String.length(safe_prompt), # Don't log full prompt for privacy
        width: config.width,
        height: config.height,
        seed: config.seed,
        num_steps: config.num_steps
      })

      case run_python_generation(Map.put(config, :prompt, safe_prompt), output_path) do
        :ok ->
          Logger.info("Z-Image-Turbo generation completed", %{output_path: output_path})
          {:ok, output_path}

        {:error, reason} ->
          Logger.error("Z-Image-Turbo generation failed", %{error: reason})
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
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

logging.getLogger("huggingface_hub").setLevel(logging.ERROR)
logging.getLogger("transformers").setLevel(logging.ERROR)
logging.getLogger("diffusers").setLevel(logging.ERROR)
os.environ["TRANSFORMERS_VERBOSITY"] = "error"
os.environ["HF_HUB_DISABLE_PROGRESS_BARS"] = "1"

from tqdm import tqdm
import warnings
warnings.filterwarnings("ignore")

_original_tqdm_init = tqdm.__init__
def _silent_tqdm_init(self, *args, **kwargs):
    kwargs['disable'] = True
    return _original_tqdm_init(self, *args, **kwargs)
tqdm.__init__ = _silent_tqdm_init

cpu_count = os.cpu_count()
half_cpu_count = cpu_count // 2
os.environ["MKL_NUM_THREADS"] = str(half_cpu_count)
os.environ["OMP_NUM_THREADS"] = str(half_cpu_count)
torch.set_num_threads(half_cpu_count)

MODEL_ID = "#{@model_id}"
device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.bfloat16 if device == "cuda" else torch.float32

# Performance optimizations (from Exa best practices)
if device == "cuda":
    torch.set_float32_matmul_precision("high")
    # Torch inductor optimizations for maximum speed
    torch._inductor.config.conv_1x1_as_mm = True
    torch._inductor.config.coordinate_descent_tuning = True
    torch._inductor.config.epilogue_fusion = False
    torch._inductor.config.coordinate_descent_check_all_directions = True

zimage_weights_dir = Path(r"#{@weights_dir}").resolve()

if zimage_weights_dir.exists() and (zimage_weights_dir / "config.json").exists():
    print(f"Loading from local directory: {zimage_weights_dir}")
    pipe = DiffusionPipeline.from_pretrained(
        str(zimage_weights_dir),
        torch_dtype=dtype,
        local_files_only=False
    )
else:
    print(f"Loading from Hugging Face Hub: {MODEL_ID}")
    pipe = DiffusionPipeline.from_pretrained(
        MODEL_ID,
        torch_dtype=dtype
    )

pipe = pipe.to(device)

# Performance optimizations for 2x speed (from Exa)
if device == "cuda":
    # Memory format optimization
    try:
        pipe.transformer.to(memory_format=torch.channels_last)
        if hasattr(pipe, 'vae') and hasattr(pipe.vae, 'decode'):
            pipe.vae.to(memory_format=torch.channels_last)
        print("[OK] Memory format optimized (channels_last)")
    except Exception as e:
        print(f"[INFO] Memory format optimization: {e}")

    # torch.compile for maximum speed (from Exa best practices)
    # Note: Requires Triton package. Falls back gracefully if not available.
    try:
        # Check if Triton is available before compiling
        import triton
        pipe.transformer = torch.compile(pipe.transformer, mode="reduce-overhead", fullgraph=False)
        if hasattr(pipe, 'vae') and hasattr(pipe.vae, 'decode'):
            pipe.vae.decode = torch.compile(pipe.vae.decode, mode="reduce-overhead", fullgraph=False)
        print("[OK] torch.compile enabled (reduce-overhead mode for 2x speed boost)")
    except ImportError:
        print("[INFO] Triton not installed - skipping torch.compile (install triton for 2x speed boost)")
    except Exception as e:
        # Catch TritonMissing and other compilation errors
        if "Triton" in str(e) or "triton" in str(e).lower():
            print("[INFO] Triton not available - skipping torch.compile (install triton for 2x speed boost)")
        else:
            print(f"[INFO] torch.compile not available: {e}")

print(f"[OK] Pipeline loaded on {device} with dtype {dtype}")

# Process generation
import time

prompt = "#{String.replace(config.prompt, "\"", "\\\"")}"
width = #{config.width}
height = #{config.height}
seed = #{config.seed}
num_steps = #{config.num_steps}
guidance_scale = #{config.guidance_scale}
output_format = "#{config.output_format}"

output_dir = Path("output")
output_dir.mkdir(exist_ok=True)

generator = torch.Generator(device=device)
if seed == 0:
    seed = generator.seed()
else:
    generator.manual_seed(seed)

# Generate image
print(f"[INFO] Starting generation: {prompt[:50]}...")
print(f"[INFO] Parameters: {width}x{height}, {num_steps} steps, seed={seed}")
print("[INFO] Generating (optimized for speed)...")
import sys
sys.stdout.flush()

# Use inference_mode for faster execution (2x speed)
with torch.inference_mode():
    output = pipe(
        prompt=prompt,
        width=width,
        height=height,
        num_inference_steps=num_steps,
        guidance_scale=guidance_scale,
        generator=generator,
    )

print("[INFO] Generation complete, processing image...")
sys.stdout.flush()

image = output.images[0]

output_path = Path("#{String.replace(output_path, "\\", "/")}")

if output_format.lower() in ["jpg", "jpeg"]:
    if image.mode == "RGBA":
        background = Image.new("RGB", image.size, (255, 255, 255))
        background.paste(image, mask=image.split()[3] if image.mode == "RGBA" else None)
        image = background
    image.save(str(output_path), "JPEG", quality=95)
else:
    image.save(str(output_path), "PNG")

print(f"[OK] Saved image to {output_path}")
print(f"OUTPUT_PATH:{output_path}")
"""

    try do
      Pythonx.eval(python_code, %{})
      :ok
    rescue
      e in Pythonx.Error ->
        {:error, "Python execution failed: #{inspect(e)}"}
    end
  end

  # Creates a secure output path with validation and timestamp
  defp create_secure_output_path(output_format) do
    with {:ok, safe_format} <- validate_output_format(output_format) do
      timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H_%M_%S")
      output_dir = Path.join(["output", timestamp])
      File.mkdir_p!(output_dir)

      filename = "zimage_#{timestamp}.#{safe_format}"

      case LivebookNx.Security.validate_filename(filename) do
        {:ok, validated_filename} ->
          output_path = Path.join(output_dir, validated_filename)
          {:ok, output_path}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Validates output format for security
  defp validate_output_format(format) when format in ["png", "jpg", "jpeg"], do: {:ok, format}
  defp validate_output_format(_), do: {:error, "Invalid output format"}
end
