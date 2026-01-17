# Forge User Guide

Forge is a comprehensive Elixir-based computation platform that provides vision-language model capabilities using Qwen3-VL, with embedded SQLite database support.

## Overview

This platform enables you to:

- Run Qwen3-VL vision-language inference on images
- Process computation tasks asynchronously with job queuing
- Store and retrieve data using embedded database and file systems
- Integrate with various third-party processing tools and utilities

## Quick Start

### Prerequisites

- Elixir 1.15+ with Erlang/OTP 26+
- Python 3.8+ (managed via uv)
- SQLite (bundled, for job queuing features)

### Installation

1. **Basic setup (no database required):**

   ```bash
   git clone <repository-url>
   cd forge
   mix deps.get
   mix compile
   ```

2. **Full setup (with database for job queuing):**
   ```bash
   mix ecto.setup                    # Create SQLite DB and run migrations
   ```

## Core Features

### Qwen3-VL Vision-Language Inference

The primary feature is running inference on Qwen3-VL models for image understanding and description.

#### Basic Usage

```bash
# Describe an image
mix qwen3vl path/to/image.jpg "What do you see in this image?"

# With custom parameters
mix qwen3vl image.png "Describe in detail" --max-tokens 200 --temperature 0.8

# Save output to file
mix qwen3vl photo.jpg "Analyze this image" --output analysis.txt
```

#### Available Options

| Option                  | Short | Default | Description                          |
| ----------------------- | ----- | ------- | ------------------------------------ |
| `--max-tokens`          | `-m`  | 4096    | Maximum tokens in response           |
| `--temperature`         | `-t`  | 0.7     | Sampling temperature (0.0-1.0)       |
| `--top-p`               |       | 0.9     | Top-p nucleus sampling               |
| `--output`              | `-o`  | stdout  | Output file path                     |
| `--use-flash-attention` |       | false   | Enable Flash Attention 2             |
| `--use-4bit`            |       | true    | Use 4-bit quantization               |
| `--full-precision`      |       | false   | Use full precision (overrides 4-bit) |

#### Model Configuration

The system automatically downloads and caches the Qwen3-VL model. Models are stored in `priv/pretrained_weights/` directory.

### Z-Image-Turbo Image Generation

Generate photorealistic images from text prompts using the Z-Image-Turbo model.

#### Basic Usage

```bash
# Generate an image
mix zimage "a beautiful sunset over mountains"

# With custom parameters
mix zimage "a cat wearing a hat" --width 512 --height 512 --seed 42

# Multiple prompts
mix zimage "cat" "dog" "bird" --width 512
```

#### Available Options

| Option             | Short | Default | Description                      |
| ------------------ | ----- | ------- | -------------------------------- |
| `--width`          | `-w`  | 1024    | Image width in pixels (64-2048)  |
| `--height`         | `-h`  | 1024    | Image height in pixels (64-2048) |
| `--seed`           | `-s`  | 0       | Random seed (0 for random)       |
| `--steps`          |       | 4       | Number of inference steps        |
| `--guidance-scale` | `-g`  | 0.0     | Guidance scale                   |
| `--format`         | `-f`  | png     | Output format: png, jpg, jpeg    |

#### Model Configuration

Z-Image-Turbo models are automatically downloaded and cached in `priv/pretrained_weights/Z-Image-Turbo/`.

### Asynchronous Job Processing

For long-running inference tasks, use the job queue system:

```elixir
# In your Elixir code
alias Forge.Qwen3VL
alias Forge.ZImage

# Queue vision-language inference
{:ok, job} = Qwen3VL.queue_inference(%{
  image_path: "path/to/image.jpg",
  prompt: "Describe this image",
  max_tokens: 100,
  temperature: 0.7
})

# Queue image generation
{:ok, job} = ZImage.queue_generation("a beautiful landscape", width: 1024, height: 1024)

# Check job status
Oban.Job.get(job.id)
```

### Database Integration

Forge uses SQLite as an embedded database for job persistence and queuing:

#### Database Setup

1. **Automatic setup:**

   ```bash
   mix ecto.setup  # Creates forge.db and runs migrations
   ```

2. **Check job queue status:**
   ```bash
   mix oban.tel    # View active jobs and workers
   ```

## Third-Party Tools Integration

The platform includes several integrated processing tools:

### Corrective Smooth Baker

For mesh processing and smoothing:

```bash
cd thirdparty/corrective_smooth_baker
python -m corrective_smooth_baker input_mesh.obj output_mesh.obj
```

### KVoiceWalk

Text-to-speech generation:

```bash
cd thirdparty/kvoicewalk
python main.py --text "Hello world" --output speech.wav
```

### Mesh Optimizer

Triangle to quad conversion:

```bash
cd thirdparty/Optimized-Tris-to-Quads-Converter
python -m tris_to_quads input.obj output.obj
```

### UniRig

Automatic rigging system:

```bash
cd thirdparty/UniRig
python run.py --input model.fbx --output rigged_model.fbx
```

## API Reference

### Core Modules

- `Forge.Qwen3VL` - Vision-language inference interface
- `Forge.Repo` - SQLite database operations
- `Forge.Application` - Application supervisor

### CLI Tasks

- `mix qwen3vl` - Run vision-language inference on images
- `mix zimage` - Generate images from text prompts
- `mix ecto.setup` - Initialize SQLite database
- `mix test` - Run test suite

## Configuration

### Environment Variables

| Variable         | Description               | Default  |
| ---------------- | ------------------------- | -------- |
| `DATABASE_PATH`  | SQLite database file path | forge.db |
| `PYTHON_VERSION` | Python version for uv     | 3.11     |

### Runtime Configuration

Edit `config/runtime.exs` for production settings:

```elixir
import Config

config :forge,
  qwen3vl: %{
    use_4bit: true,
    use_flash_attention: false,
    default_max_tokens: 4096
  }

config :forge, Forge.Repo,
  database: System.get_env("DATABASE_PATH") || "forge_prod.db"
```

## Troubleshooting

### Common Issues

1. **Model download fails:**
   - Check internet connection
   - Verify HuggingFace access
   - Clear `priv/pretrained_weights/` and retry

2. **Python environment issues:**
   - Run `mix compile` to reinitialize Pythonx
   - Check Python version compatibility

3. **Database connection errors:**
   - Verify SQLite database exists: `ls *.db`
   - Run migrations: `mix ecto.migrate`
   - Check permissions on database file

4. **Memory issues:**
   - Use `--use-4bit` for lower memory usage
   - Reduce `max-tokens` for smaller responses
   - Consider CPU-only mode if GPU memory is limited

### Performance Tuning

- **GPU Acceleration:** Ensure CUDA-compatible GPU for best performance
- **Quantization:** Use 4-bit quantization to reduce memory usage
- **Batch Processing:** Queue multiple jobs for efficient processing
- **Caching:** Models are cached locally after first download

## Development

### Running Tests

```bash
mix test
```

### Adding New Features

1. Create new modules in `lib/forge/`
2. Add tests in `test/`
3. Update documentation
4. Submit pull request

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed contribution guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
