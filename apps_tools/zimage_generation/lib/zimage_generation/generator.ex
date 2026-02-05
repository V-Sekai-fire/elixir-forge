defmodule ZImageGeneration.Generator do
  @moduledoc """
  Membrane generator element for Z-Image AI generation.

  Receives ZImageGeneration.Data from source, performs AI image generation,
  and outputs completed data with output paths.
  """

  use Membrane.Filter
  alias ZImageGeneration.Data
  require OpenTelemetry.Tracer

  def_input_pad :input, accepted_format: ZImageGeneration.Data
  def_output_pad :output, accepted_format: ZImageGeneration.Data

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %{setup_complete: false}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    actions = [demand: {:input, 1}]
    {actions, state}
  end

  @impl true
  def handle_buffer(:input, %Membrane.Buffer{payload: %ZImageGeneration.Data{} = data}, _ctx, state) do
    case generate_image(data) do
      {:ok, output_path} ->
        completed_data = Data.complete(data, output_path)
        actions = [buffer: {:output, completed_data}, demand: {:input, 1}]

        OpenTelemetry.Tracer.with_span "zimage.generator.success" do
          OpenTelemetry.Tracer.set_attribute("generator.output_path", output_path)
          OpenTelemetry.Tracer.set_status(:ok)
        end

        {actions, state}

      {:error, reason} ->
        OpenTelemetry.Tracer.with_span "zimage.generator.error" do
          OpenTelemetry.Tracer.set_attribute("generator.error", inspect(reason))
          OpenTelemetry.Tracer.set_status(:error, inspect(reason))
        end

        {[demand: {:input, 1}, notify_parent: {:generation_failed, reason}], state}
    end
  end

  @impl true
  def handle_event(_pad, _event, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {[end_of_stream: :output], state}
  end

  # Private functions

  def generate_image(data) do
    OpenTelemetry.Tracer.with_span "zimage.generator.generate_image" do
      OpenTelemetry.Tracer.set_attribute("image.width", data.width)
      OpenTelemetry.Tracer.set_attribute("image.height", data.height)
      OpenTelemetry.Tracer.set_attribute("image.seed", data.seed)
      OpenTelemetry.Tracer.set_attribute("image.num_steps", data.num_steps)
      OpenTelemetry.Tracer.set_attribute("image.guidance_scale", data.guidance_scale)
      OpenTelemetry.Tracer.set_attribute("prompt.length", String.length(data.prompt))

      try do
        # Create output directory
        output_dir = Path.expand("output")
        File.mkdir_p!(output_dir)

        # Create timestamped folder
        tag = time_tag()
        export_dir = Path.join(output_dir, tag)
        File.mkdir_p!(export_dir)

        # Load pipeline (reusing from original implementation)
        load_code = create_load_code()

        # Generate with pipeline
        generate_code = create_generate_code(data, tag)

        # Pass config data via globals to avoid JSON parsing issues
        config_data = Jason.encode!(%{
          prompt: data.prompt,
          width: data.width,
          height: data.height,
          seed: data.seed,
          num_steps: data.num_steps,
          guidance_scale: data.guidance_scale,
          output_format: data.output_format,
          tag: tag
        })

        # Execute Python generation (load first, then generate)
        {_, globals_after_load} = Pythonx.eval(load_code, %{})

        # Generate with the pipeline and config data in globals
        {result, _globals_after_generate} = Pythonx.eval(generate_code, Map.put(globals_after_load, "config_json", config_data))

        # Result should be the output path string from Python
        case result do
          %Pythonx.Object{} = py_obj ->
            case Pythonx.decode(py_obj) do
              path when is_binary(path) -> {:ok, path}
              other -> {:error, "Expected string path, got: #{inspect(other)}"}
            end
          path when is_binary(path) -> {:ok, path}
          other -> {:error, "Failed to generate image, result was: #{inspect(other)}"}
        end

      rescue
        e ->
          {:error, Exception.message(e)}
      end
    end
  end

  defp create_load_code do
    ~S"""
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

MODEL_ID = "Tongyi-MAI/Z-Image-Turbo"

# Always use CPU for test environment - simplified device detection
print("[INFO] Using CPU-only mode for test environment")
device = "cpu"
dtype = torch.float32

# Performance optimizations (from Exa best practices)
if device == "cuda":
    torch.set_float32_matmul_precision("high")
    # Torch inductor optimizations for maximum speed
    torch._inductor.config.conv_1x1_as_mm = True
    torch._inductor.config.coordinate_descent_tuning = True
    torch._inductor.config.epilogue_fusion = False
    torch._inductor.config.coordinate_descent_check_all_directions = True

# For test environment, always load from Hugging Face Hub
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

    # torch.compile is disabled due to CUDA stream issues
    print("[INFO] torch.compile disabled (causes CUDA stream issues with current setup)")
else:
    print("[INFO] torch.compile not applicable for CPU generation")

print(f"[OK] Pipeline loaded on {device} with dtype {dtype}")

"""
  end

  defp create_generate_code(_data, _tag) do
    ~S"""
# Process generation
import json
import time
from pathlib import Path
from PIL import Image

# Read configuration from globals
config = json.loads(config_json)

prompt = config.get('prompt')
width = config.get('width', 1024)
height = config.get('height', 1024)
seed = config.get('seed', 0)
num_steps = config.get('num_steps', 4)
guidance_scale = config.get('guidance_scale', 0.0)
output_format = config.get('output_format', 'png')
tag = config.get('tag')

output_dir = Path("output")
tag = time.strftime("%Y%m%d_%H_%M_%S")
export_dir = output_dir / tag
export_dir.mkdir(exist_ok=True)

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
with torch.inference_mode() if hasattr(torch.cuda, 'is_available') else torch.no_grad():
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

output_filename = f"zimage_{tag}.{output_format}"
output_path = export_dir / output_filename

if output_format.lower() in ["jpg", "jpeg"]:
    if image.mode == "RGBA":
        background = Image.new("RGB", image.size, (255, 255, 255))
        background.paste(image, mask=image.split()[3] if image.mode == "RGBA" else None)
        image = background
    image.save(str(output_path), "JPEG", quality=95)
else:
    image.save(str(output_path), "PNG")

print(f"[OK] Saved image to {output_path}")
str(output_path)

"""
  end



  defp time_tag do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.to_string()
    |> String.replace(["-", ":", "."], "_")
    |> String.slice(0, 19)
  end
end