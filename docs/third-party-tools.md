# Third-Party Tools Guide

Forge includes several integrated third-party processing tools for various computer vision and graphics tasks. This guide explains how to use each tool effectively.

## Overview

The platform integrates the following third-party tools:

- **Corrective Smooth Baker** - Mesh smoothing and corrective shape keys
- **KVoiceWalk** - Text-to-speech synthesis
- **Mesh Optimizer** - Triangle to quad conversion
- **Optimized Tris-to-Quads Converter** - Advanced mesh optimization
- **Robust Skin Weights Transfer** - Character rigging utilities
- **UniRig** - Automatic rigging system
- **Z-Image-Turbo** - Image generation and editing _(integrated into main application)_

## Corrective Smooth Baker

Advanced mesh processing tool for creating corrective shape keys and smooth deformations.

### Features

- Corrective shape key generation
- Mesh smoothing algorithms
- Deformation analysis
- Shape key optimization

### Usage

#### Command Line

```bash
cd thirdparty/corrective_smooth_baker

# Basic smoothing
python -m corrective_smooth_baker input_mesh.obj output_mesh.obj

# With corrective shape keys
python -m corrective_smooth_baker \
  --input input_mesh.obj \
  --output output_mesh.obj \
  --corrective-shapes \
  --iterations 3 \
  --smooth-factor 0.5
```

#### Python API

```python
from corrective_smooth_baker import CorrectiveSmoothBaker

# Initialize baker
baker = CorrectiveSmoothBaker()

# Process mesh
result = baker.process_mesh(
    input_path="input.obj",
    output_path="output.obj",
    generate_corrective=True,
    smooth_iterations=3
)
```

### Parameters

| Parameter             | Type  | Default  | Description                    |
| --------------------- | ----- | -------- | ------------------------------ |
| `--input`             | file  | required | Input mesh file (.obj, .fbx)   |
| `--output`            | file  | required | Output mesh file               |
| `--corrective-shapes` | flag  | false    | Generate corrective shape keys |
| `--iterations`        | int   | 3        | Smoothing iterations           |
| `--smooth-factor`     | float | 0.5      | Smoothing intensity (0.0-1.0)  |
| `--preserve-details`  | flag  | false    | Preserve fine details          |

### Integration with Forge

```elixir
defmodule Forge.MeshProcessing do
  alias Forge.CorrectiveSmoothBaker

  def smooth_mesh(input_path, output_path) do
    CorrectiveSmoothBaker.process(input_path, output_path, %{
      corrective_shapes: true,
      iterations: 3,
      smooth_factor: 0.5
    })
  end
end
```

## KVoiceWalk

Neural text-to-speech synthesis with voice walking capabilities.

### Features

- High-quality voice synthesis
- Voice style interpolation
- Multiple language support
- Emotion control

### Usage

#### Basic Synthesis

```bash
cd thirdparty/kvoicewalk

# Simple text-to-speech
python main.py --text "Hello, world!" --output hello.wav

# With voice style
python main.py \
  --text "Welcome to Forge" \
  --output welcome.wav \
  --voice female_casual \
  --emotion happy
```

#### Voice Walking

```bash
# Interpolate between voices
python main.py \
  --text "This is a test" \
  --output interpolated.wav \
  --voice-start male_formal \
  --voice-end female_casual \
  --steps 10
```

### Parameters

| Parameter   | Type   | Default  | Description                                    |
| ----------- | ------ | -------- | ---------------------------------------------- |
| `--text`    | string | required | Text to synthesize                             |
| `--output`  | file   | required | Output audio file (.wav)                       |
| `--voice`   | string | default  | Voice style (male_formal, female_casual, etc.) |
| `--emotion` | string | neutral  | Emotional tone                                 |
| `--speed`   | float  | 1.0      | Speech speed multiplier                        |
| `--pitch`   | float  | 0.0      | Pitch adjustment (-1.0 to 1.0)                 |
| `--volume`  | float  | 1.0      | Volume multiplier                              |

### Voice Styles

- `male_formal` - Professional male voice
- `female_casual` - Casual female voice
- `male_casual` - Casual male voice
- `female_formal` - Professional female voice
- `child` - Young voice
- `elder` - Mature voice

### Integration

```elixir
defmodule Forge.TextToSpeech do
  alias Forge.KVoiceWalk

  def synthesize(text, options \\ %{}) do
    KVoiceWalk.synthesize(text, %{
      voice: options[:voice] || "female_casual",
      emotion: options[:emotion] || "neutral",
      output_path: options[:output_path]
    })
  end
end
```

## Mesh Optimizer

Triangle to quad conversion and mesh optimization utilities.

### Features

- Automatic quad conversion
- Mesh simplification
- Topology optimization
- UV preservation

### Usage

#### Basic Conversion

```bash
cd thirdparty/meshoptimizer

# Triangle to quad conversion
python meshoptimizer.py input.obj output.obj --quads

# Mesh simplification
python meshoptimizer.py input.obj output.obj --simplify 0.5
```

#### Advanced Optimization

```bash
# Full optimization pipeline
python meshoptimizer.py \
  --input input.obj \
  --output optimized.obj \
  --quads \
  --simplify 0.8 \
  --smooth \
  --preserve-uv \
  --iterations 2
```

### Parameters

| Parameter       | Type  | Default  | Description                    |
| --------------- | ----- | -------- | ------------------------------ |
| `--input`       | file  | required | Input mesh file                |
| `--output`      | file  | required | Output mesh file               |
| `--quads`       | flag  | false    | Convert triangles to quads     |
| `--simplify`    | float | -        | Simplification ratio (0.0-1.0) |
| `--smooth`      | flag  | false    | Apply smoothing                |
| `--preserve-uv` | flag  | false    | Preserve UV coordinates        |
| `--iterations`  | int   | 1        | Optimization iterations        |

## Optimized Tris-to-Quads Converter

Advanced triangle to quad conversion with quality optimization.

### Features

- Quality-based quad generation
- Angle and shape preservation
- Interactive parameter tuning
- Batch processing

### Usage

#### Command Line

```bash
cd thirdparty/Optimized-Tris-to-Quads-Converter

# Basic conversion
python -m tris_to_quads input.obj output.obj

# With quality settings
python -m tris_to_quads \
  --input input.obj \
  --output output.obj \
  --max-angle 120 \
  --min-area 0.01 \
  --iterations 5
```

#### GUI Mode

```bash
# Interactive mode
python -m tris_to_quads --gui input.obj
```

### Parameters

| Parameter               | Type  | Default  | Description                  |
| ----------------------- | ----- | -------- | ---------------------------- |
| `--input`               | file  | required | Input mesh file              |
| `--output`              | file  | required | Output mesh file             |
| `--max-angle`           | float | 120      | Maximum quad angle (degrees) |
| `--min-area`            | float | 0.01     | Minimum quad area            |
| `--iterations`          | int   | 3        | Optimization iterations      |
| `--preserve-boundaries` | flag  | true     | Preserve mesh boundaries     |
| `--gui`                 | flag  | false    | Launch GUI interface         |

### Quality Metrics

The converter optimizes for:

- Quad regularity (aspect ratio)
- Angle distribution
- Surface area preservation
- Boundary integrity

## Robust Skin Weights Transfer

Advanced character rigging and skin weight transfer utilities.

### Features

- Automatic weight transfer
- Pose space deformation
- Corrective blend shapes
- Multi-resolution transfer

### Usage

#### Weight Transfer

```bash
cd thirdparty/RobustSkinWeightsTransfer

# Basic transfer
python transfer_weights.py \
  --source source_mesh.obj \
  --target target_mesh.obj \
  --source-weights source_weights.json \
  --output target_weights.json

# Advanced transfer
python transfer_weights.py \
  --source source.fbx \
  --target target.fbx \
  --method multi_resolution \
  --corrective-blends \
  --pose-space
```

### Parameters

| Parameter             | Type   | Default       | Description                |
| --------------------- | ------ | ------------- | -------------------------- |
| `--source`            | file   | required      | Source mesh with weights   |
| `--target`            | file   | required      | Target mesh                |
| `--source-weights`    | file   | required      | Source weight file         |
| `--output`            | file   | required      | Output weight file         |
| `--method`            | string | closest_point | Transfer method            |
| `--corrective-blends` | flag   | false         | Generate corrective shapes |
| `--pose-space`        | flag   | false         | Use pose space deformation |

### Transfer Methods

- `closest_point` - Simple closest point mapping
- `barycentric` - Barycentric coordinate transfer
- `harmonic` - Harmonic function interpolation
- `multi_resolution` - Multi-resolution transfer

## UniRig

Automatic rigging system for 3D characters.

### Features

- Automatic bone placement
- IK/FK setup
- Control rig generation
- Animation retargeting

### Usage

#### Basic Rigging

```bash
cd thirdparty/UniRig

# Automatic rigging
python run.py \
  --input character.obj \
  --output rigged_character.fbx \
  --template biped

# Custom configuration
python run.py \
  --input character.fbx \
  --output rigged.fbx \
  --config custom_rig.json \
  --ik-solvers \
  --facial-rig
```

### Parameters

| Parameter           | Type   | Default  | Description               |
| ------------------- | ------ | -------- | ------------------------- |
| `--input`           | file   | required | Input character mesh      |
| `--output`          | file   | required | Output rigged character   |
| `--template`        | string | biped    | Rig template              |
| `--config`          | file   | -        | Custom configuration file |
| `--ik-solvers`      | flag   | false    | Add IK solvers            |
| `--facial-rig`      | flag   | false    | Include facial rigging    |
| `--animation-ready` | flag   | true     | Prepare for animation     |

### Rig Templates

- `biped` - Humanoid character
- `quadruped` - Four-legged animal
- `bird` - Avian character
- `custom` - User-defined template

## Z-Image-Turbo

Advanced image generation and editing with turbo acceleration.

### Features

- High-speed image generation
- Image-to-image editing
- Inpainting and outpainting
- Style transfer

### Usage

#### Image Generation

```bash
cd thirdparty/Z-Image-Turbo

# Text-to-image
python -m zimage_turbo generate \
  --prompt "A beautiful landscape" \
  --output landscape.png \
  --width 1024 \
  --height 768

# Image-to-image
python -m zimage_turbo edit \
  --input source.jpg \
  --prompt "Add a sunset sky" \
  --output edited.jpg \
  --strength 0.75
```

#### Inpainting

```bash
# Remove and replace objects
python -m zimage_turbo inpaint \
  --input image.jpg \
  --mask mask.png \
  --prompt "A beautiful garden" \
  --output inpainted.jpg
```

### Parameters

| Parameter          | Type   | Default  | Description              |
| ------------------ | ------ | -------- | ------------------------ |
| `--prompt`         | string | required | Text description         |
| `--input`          | file   | -        | Input image for editing  |
| `--output`         | file   | required | Output image file        |
| `--width`          | int    | 512      | Image width              |
| `--height`         | int    | 512      | Image height             |
| `--strength`       | float  | 0.8      | Edit strength (0.0-1.0)  |
| `--guidance-scale` | float  | 7.5      | Classifier-free guidance |
| `--steps`          | int    | 20       | Inference steps          |
| `--seed`           | int    | random   | Random seed              |

## Integration Examples

### Pipeline Processing

```elixir
defmodule Forge.ProcessingPipeline do
  alias Forge.{Qwen3VL, MeshProcessing, TextToSpeech}

  def process_3d_scene(image_path, mesh_path) do
    # Analyze image with vision model
    {:ok, description} = Qwen3VL.do_inference(%{
      image_path: image_path,
      prompt: "Describe this 3D scene in detail"
    })

    # Generate audio description
    audio_path = "output/description.wav"
    TextToSpeech.synthesize(description, %{output_path: audio_path})

    # Process mesh
    optimized_mesh = "output/optimized.obj"
    MeshProcessing.optimize_mesh(mesh_path, optimized_mesh)

    %{
      description: description,
      audio: audio_path,
      mesh: optimized_mesh
    }
  end
end
```

### Batch Processing

```elixir
defmodule Forge.BatchProcessor do
  alias Forge.MeshProcessing

  def process_mesh_batch(input_dir, output_dir) do
    Path.wildcard("#{input_dir}/*.obj")
    |> Enum.map(&Task.async(fn ->
      input_path = &1
      filename = Path.basename(input_path)
      output_path = Path.join(output_dir, "optimized_#{filename}")

      MeshProcessing.optimize_mesh(input_path, output_path)
      output_path
    end))
    |> Enum.map(&Task.await(&1, 300_000))
  end
end
```

## Performance Optimization

### GPU Acceleration

Most tools support GPU acceleration:

```bash
# Enable GPU for mesh processing
export CUDA_VISIBLE_DEVICES=0
python -m corrective_smooth_baker --gpu input.obj output.obj
```

### Memory Management

```python
# Limit memory usage
import os
os.environ['PYTORCH_CUDA_ALLOC_CONF'] = 'max_split_size_mb:512'
```

### Parallel Processing

```elixir
# Process multiple files in parallel
files
|> Enum.chunk_every(4)  # Process 4 files concurrently
|> Enum.map(&Task.async(fn chunk ->
  Enum.map(chunk, &process_file/1)
end))
|> Enum.flat_map(&Task.await/1)
```

## Error Handling

### Common Issues

1. **Memory errors:**

   ```python
   # Reduce batch size or use CPU
   os.environ['CUDA_VISIBLE_DEVICES'] = ''
   ```

2. **File format issues:**

   ```python
   # Check supported formats
   from mesh_processor import supported_formats
   print(supported_formats())
   ```

3. **GPU compatibility:**
   ```bash
   # Check GPU compatibility
   nvidia-smi
   python -c "import torch; print(torch.cuda.is_available())"
   ```

### Logging and Debugging

```python
import logging
logging.basicConfig(level=logging.DEBUG)

# Enable verbose output
tool.process(input, output, verbose=True)
```

## Contributing

### Adding New Tools

1. Create tool directory under `thirdparty/`
2. Add Python requirements file
3. Implement Elixir wrapper module
4. Update this documentation
5. Add integration tests

### Tool Standards

- Include comprehensive README
- Provide command-line interface
- Support both Python API and CLI
- Include example usage
- Document all parameters
- Handle errors gracefully
