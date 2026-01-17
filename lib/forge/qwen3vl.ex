defmodule Forge.Qwen3VL do
  @moduledoc """
  Qwen3-VL Vision-Language Model Integration.

  Provides full Bumblebee-compatible APIs for Qwen3-VL vision-language inference
  using Pythonx for model execution.

  ## Examples

      # Bumblebee-compatible usage
      {:ok, model_info} = Forge.Qwen3VL.qwen3_vl()

      serving = Bumblebee.TextToText.new_text_to_text(model_info)
      {:ok, result} = Bumblebee.Serving.run(serving, %{text: "Describe this image", images: [image_tensor]})

      # Direct usage (for advanced users)
      {:ok, model} = Forge.Qwen3VL.load_model()
      {:ok, result} = Forge.Qwen3VL.inference(model, params)
  """

  require Logger

  alias SpanCollector
  alias HuggingFaceDownloader

  @model_id "huihui-ai/Huihui-Qwen3-VL-4B-Instruct-abliterated"
  @weights_dir "priv/pretrained_weights/Huihui-Qwen3-VL-4B-Instruct-abliterated"

  # Bumblebee-compatible model spec struct
  defstruct [
    # Model identifiers
    :architecture,
    :model_name,

    # Components (for Bumblebee compatibility)
    :tokenizer,
    :model,
    :model_info,

    # Configuration
    :task,
    :backend,

    # Processing functions (Python-based)
    :preprocessing_fun,
    :generation_fun,
    :postprocessing_fun,

    # Pythonx-specific
    :weights_dir,
    :loaded?
  ]

  @doc """
  Loads the Qwen3-VL model configuration.

  This function provides Bumblebee-compatible model specification for Qwen3-VL.
  The returned spec can be used with Bumblebee.TextToText.new_text_to_text/1.

  ## Options
  - `:cache_dir` - Directory for model weights (default: priv/pretrained_weights)
  - `:backend` - Backend configuration for performance optimization
  - `:use_flash_attention` - Enable Flash Attention 2 (default: false)
  - `:use_4bit` - Use 4-bit quantization (default: true)
  """
  @spec qwen3_vl(keyword()) :: {:ok, map()} | {:error, term()}
  def qwen3_vl(opts \\ []) do
    cache_dir = Keyword.get(opts, :cache_dir, @weights_dir)
    model_dir = Path.join(cache_dir, @model_id)

    # Ensure directory structure
    File.mkdir_p!(cache_dir)

    # Bumblebee-compatible model specification
    {:ok, %{
      architecture: :text_to_text,  # Vision-language is treated as text-to-text with images
      model_name: @model_id,
      model_info: %{
        type: :qwen3_vl,
        model_id: @model_id,
        model_dir: model_dir,
        use_flash_attention: Keyword.get(opts, :use_flash_attention, false),
        use_4bit: Keyword.get(opts, :use_4bit, true),
        backend: Keyword.get(opts, :backend, default_backend_opts())
      },
      # Bumblebee serving specification
      serving_spec: %{
        task: :text_generation,
        preprocess: &__MODULE__.preprocess/1,
        generate: &__MODULE__.generate_fun/1,
        postprocess: &__MODULE__.postprocess/1
      },
      # Tokenization (placeholder - Python handles this)
      tokenizer: nil,
      # Parameter specifications (Bumblebee format)
      parameters: %{
        max_new_tokens: 4096,
        temperature: 0.7,
        top_p: 0.9,
        pad_token_id: 0,
        eos_token_id: 2
      }
    }}
  end

  @doc """
  Loads a pretrained model for direct usage.

  Provides a lower-level interface for advanced users who want direct access
  to the Pythonx-backed model without Bumblebee layers.

  ## Options
  - `:cache_dir` - Directory for model weights (default: priv/pretrained_weights/${model_id})
  - `:backend` - Backend configuration for performance optimization
  """
  @spec load_model(keyword()) :: {:ok, %__MODULE__{}} | {:error, term()}
  def load_model(opts \\ []) do
    cache_dir = Keyword.get(opts, :cache_dir, @weights_dir)

    # Ensure model directory structure
    model_dir = Path.join(cache_dir, @model_id)
    File.mkdir_p!(cache_dir)

    struct = %__MODULE__{
      architecture: :text_to_text,
      model_name: @model_id,
      model_info: %{
        type: :qwen3_vl,
        model_id: @model_id,
        use_flash_attention: Keyword.get(opts, :use_flash_attention, false),
        use_4bit: Keyword.get(opts, :use_4bit, true)
      },
      task: :text_generation,
      backend: Keyword.get(opts, :backend, default_backend_opts()),
      preprocessing_fun: &__MODULE__.preprocess/1,
      generation_fun: &__MODULE__.generate_fun/1,
      postprocessing_fun: &__MODULE__.postprocess/1,
      weights_dir: model_dir,
      loaded?: false
    }

    # Check if model is already downloaded
    loaded? = File.exists?(model_dir) && File.exists?(Path.join(model_dir, "config.json"))

    {:ok, %{struct | loaded?: loaded?}}
  end

  @doc """
  Runs inference on the model.

  Follows Bumblebee's `serving.run()` pattern with parameters configuration.

  ## Parameters
  - `:image_path` - Path to input image (required)
  - `:prompt` - Text prompt describing the task (required)
  - `:max_tokens` - Maximum tokens in response (default: 4096)
  - `:temperature` - Sampling temperature 0.0-1.0 (default: 0.7)
  - `:top_p` - Top-p nucleus sampling (default: 0.9)
  - `:use_flash_attention` - Enable Flash Attention 2 (default: false)
  - `:use_4bit` - Use 4-bit quantization (default: true)
  """
  @spec inference(%__MODULE__{}, map()) :: {:ok, String.t()} | {:error, term()}
  def inference(%__MODULE__{} = model, params) do
    # Validate parameters
    with {:ok, validated_params} <- validate_infer_params(params),
         {:ok, config} <- build_config(validated_params) do

      # Download model if needed
      if !model.loaded? do
        download_model()
      end

      # Run inference
      do_inference(config)
    end
  end

  @doc """
  Builds a serving for repeated inference.

  Similar to Bumblebee's serving pattern but simplified for single inference.
  """
  @spec serving(%__MODULE__{}, keyword()) :: %__MODULE__{}
  def serving(%__MODULE__{} = model, _opts \\ []) do
    model
  end

  @doc """
  Generates text from image and prompt.

  Simple alias for inference/2, follows Bumblebee naming conventions.
  """
  @spec generate(%__MODULE__{}, map()) :: {:ok, String.t()} | {:error, term()}
  def generate(model, params), do: inference(model, params)

  @doc """
  Creates a basic inference configuration.

  ## Compatibility
  This function is kept for backward compatibility with existing code
  and Mix tasks. For new code, prefer `load_model()` + `inference()`.
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      image_path: opts[:image_path],
      prompt: opts[:prompt],
      max_tokens: opts[:max_tokens] || 4096,
      temperature: opts[:temperature] || 0.7,
      top_p: opts[:top_p] || 0.9,
      use_flash_attention: opts[:use_flash_attention] || false,
      use_4bit: opts[:use_4bit] || true
    }
  end

  # Compatibility function for Mix task interface
  def run(%__MODULE__{} = config_struct) do
    # Convert struct to map format expected by inference/2
    params = Map.from_struct(config_struct)
    model = elem(load_model(), 1)
    inference(model, params)
  end

  # Legacy map-based run function for backward compatibility
  def run(config_map) when is_map(config_map) and not is_struct(config_map) do
    model = elem(load_model(), 1)
    inference(model, config_map)
  end

  # Bumblebee-style API helpers
  defp default_backend_opts do
    [
      seed: :erlang.system_time(:second),
      compiler: :none,  # We use Pythonx, not Nx
      client: :none
    ]
  end

  defp validate_infer_params(params) do
    # Validate required parameters
    image_path = params[:image_path]
    prompt = params[:prompt]

    cond do
      !image_path ->
        {:error, "image_path is required"}
      !File.exists?(image_path) ->
        {:error, "Image file not found: #{image_path}"}
      !prompt || prompt == "" ->
        {:error, "prompt is required and cannot be empty"}
      true ->
        {:ok, params}
    end
  end

  defp build_config(validated_params) do
    config = %{
      image_path: validated_params[:image_path],
      prompt: validated_params[:prompt],
      max_tokens: validated_params[:max_tokens] || 4096,
      temperature: validated_params[:temperature] || 0.7,
      top_p: validated_params[:top_p] || 0.9,
      use_flash_attention: validated_params[:use_flash_attention] || false,
      use_4bit: validated_params[:use_4bit] || true
    }

    {:ok, config}
  end

  # Bumblebee-compatible preprocessing function
  @doc false
  def preprocess(%{text: prompt, images: images} = inputs) do
    # Convert Bumblebee format to Forge format
    # Handle single image or list of images
    image_path = case images do
      [{_image_tensor, _ }] -> "bumblebee_image.jpg" # TODO: convert tensor
      [] -> raise "No image provided"
      _ -> raise "Multiple images not supported in this integration"
    end

    %{
      prompt: prompt,
      image_path: image_path,
      max_tokens: inputs[:max_new_tokens] || 4096,
      temperature: inputs[:temperature] || 0.7,
      top_p: inputs[:top_p] || 0.9
    }
  end

  # Bumblebee-compatible generation function
  @doc false
  def generate_fun(params) do
    # This would be called by Bumblebee serving
    # For now, delegate to direct inference
    case Forge.Qwen3VL.inference_encoded(params) do
      {:ok, text} -> %{text: text}
      {:error, reason} -> raise "Generation failed: #{inspect(reason)}"
    end
  end

  # Bumblebee-compatible postprocessing function
  @doc false
  def postprocess(%{text: text}) do
    # Simple postprocessing - add more logic as needed
    %{text: text}
  end

  # Encoded inference for serving system
  @doc false
  def inference_encoded(params) do
    model = elem(load_model(), 1)
    inference(model, params)
  end

  # Legacy validation - kept for compatibility
  defp validate_config(config) do
    unless config.image_path && File.exists?(config.image_path) do
      raise "Image file not found: #{config.image_path}"
    end

    unless config.prompt do
      raise "Prompt is required"
    end
  end

  defp download_model do
    # Use shared downloader
    case HuggingFaceDownloader.download_repo(@model_id, @weights_dir, "Qwen3-VL", false) do
      {:ok, _} -> :ok
      {:error, _} -> Logger.warning("Model download had errors, continuing...")
    end
  end

  defp do_inference(config) do
    # Python environment is initialized automatically via config

    # Python code for inference (adapted from script)
    python_code = """
import json
import sys
import os
from pathlib import Path
import torch
from PIL import Image
from transformers import Qwen3VLForConditionalGeneration, AutoProcessor, BitsAndBytesConfig

# Model setup
MODEL_ID = "#{@model_id}"
device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.bfloat16 if device == "cuda" else torch.float32

quantization_config = None
if #{if config.use_4bit, do: "True", else: "False"} and device == "cuda":
    quantization_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_compute_dtype=torch.bfloat16,
        bnb_4bit_use_double_quant=True,
        bnb_4bit_quant_type="nf4"
    )
    dtype = None

load_kwargs = {
    "device_map": "auto",
    "trust_remote_code": True,
    "low_cpu_mem_usage": True,
    "attn_implementation": "flash_attention_2" if #{if config.use_flash_attention, do: "True", else: "False"} else "sdpa",
}

if quantization_config:
    load_kwargs["quantization_config"] = quantization_config
elif dtype:
    load_kwargs["dtype"] = dtype

model_path = "#{@weights_dir}"
if Path(model_path).exists() and (Path(model_path) / "config.json").exists():
    model = Qwen3VLForConditionalGeneration.from_pretrained(model_path, **load_kwargs)
else:
    model = Qwen3VLForConditionalGeneration.from_pretrained(MODEL_ID, **load_kwargs)

processor = AutoProcessor.from_pretrained(MODEL_ID, trust_remote_code=True)

# Load image
image = Image.open("#{config.image_path}").convert("RGB")

# Prepare messages
messages = [
    {
        "role": "user",
        "content": [
            {"type": "image", "image": "#{config.image_path}"},
            {"type": "text", "text": "#{String.replace(config.prompt, "\"", "\\\"")}"},
        ],
    }
]

inputs = processor.apply_chat_template(
    messages,
    tokenize=True,
    add_generation_prompt=True,
    return_dict=True,
    return_tensors="pt"
).to(model.device)

# Generate
generated_ids = model.generate(
    **inputs,
    max_new_tokens=#{config.max_tokens},
    temperature=#{config.temperature},
    top_p=#{config.top_p},
    do_sample=#{if config.temperature > 0.0, do: "True", else: "False"},
)

generated_ids_trimmed = [
    out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
]

output_text = processor.batch_decode(
    generated_ids_trimmed,
    skip_special_tokens=True,
    clean_up_tokenization_spaces=False
)

response = output_text[0] if output_text else ""
print(response)
"""

    {result, _} = Pythonx.eval(python_code, %{})
    result
  end

  @doc """
  Run Qwen3-VL inference synchronously.

  ## Parameters
  - `image_path` - Path to the input image
  - `prompt` - Text prompt for the model
  - `opts` - Additional options

  ## Options
  - `:max_tokens` - Maximum tokens to generate (default: 4096)
  - `:temperature` - Sampling temperature (default: 0.7)
  - `:top_p` - Top-p sampling (default: 0.9)
  - `:output_path` - Path to save results (optional)
  - `:use_flash_attention` - Use flash attention (default: false)
  - `:use_4bit` - Use 4-bit quantization (default: true)

  ## Examples

      iex> Forge.Qwen3VL.infer("image.jpg", "Describe this image")
      {:ok, "The image shows..."}
  """
  def infer(image_path, prompt, opts \\ []) do
    config = %{
      image_path: image_path,
      prompt: prompt,
      max_tokens: Keyword.get(opts, :max_tokens, 4096),
      temperature: Keyword.get(opts, :temperature, 0.7),
      top_p: Keyword.get(opts, :top_p, 0.9),
      output_path: Keyword.get(opts, :output_path),
      use_flash_attention: Keyword.get(opts, :use_flash_attention, false),
      use_4bit: Keyword.get(opts, :use_4bit, true)
    }

    # Validate config (raises on error)
    validate_config(struct(__MODULE__, config))

    run(struct(__MODULE__, config))
  end
end
