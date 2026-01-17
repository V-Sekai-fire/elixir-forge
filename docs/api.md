# Livebook Nx API Reference

This document provides comprehensive API documentation for the Livebook Nx platform.

## Core Modules

### LivebookNx.Qwen3VL

Main module for Qwen3-VL vision-language inference.

#### Functions

##### `do_inference(config)`

Runs synchronous inference on an image.

**Parameters:**

- `config` (map): Configuration map with keys:
  - `:image_path` (string, required): Path to input image
  - `:prompt` (string, required): Text prompt for the model
  - `:max_tokens` (integer): Maximum tokens in response (default: 4096)
  - `:temperature` (float): Sampling temperature 0.0-1.0 (default: 0.7)
  - `:top_p` (float): Top-p nucleus sampling (default: 0.9)
  - `:use_4bit` (boolean): Use 4-bit quantization (default: true)
  - `:use_flash_attention` (boolean): Enable Flash Attention 2 (default: false)

**Returns:**

- `{:ok, response}` - Successful inference with text response
- `{:error, reason}` - Error with reason

**Example:**

```elixir
config = %{
  image_path: "photo.jpg",
  prompt: "Describe this image",
  max_tokens: 100,
  temperature: 0.8
}

{:ok, description} = LivebookNx.Qwen3VL.do_inference(config)
```

##### `queue_inference(config)`

Queues an inference job for asynchronous processing.

**Parameters:**

- `config` (map): Same as `do_inference/1`

**Returns:**

- `{:ok, job}` - Job queued successfully
- `{:error, changeset}` - Validation error

**Example:**

```elixir
{:ok, job} = LivebookNx.Qwen3VL.queue_inference(%{
  image_path: "image.png",
  prompt: "What is in this image?",
  max_tokens: 200
})
```

##### `validate_config(config)`

Validates inference configuration parameters.

**Parameters:**

- `config` (map): Configuration to validate

**Returns:**

- `:ok` - Valid configuration
- `{:error, errors}` - Validation errors

### LivebookNx.ZImage

Main module for Z-Image-Turbo image generation.

#### Functions

##### `generate(prompt, opts)`

Generates an image from a text prompt.

**Parameters:**

- `prompt` (string, required): Text description of the image to generate
- `opts` (keyword list): Configuration options

**Options:**

- `:width` (integer): Image width in pixels (64-2048, default: 1024)
- `:height` (integer): Image height in pixels (64-2048, default: 1024)
- `:seed` (integer): Random seed (0 for random, default: 0)
- `:num_steps` (integer): Number of inference steps (default: 4)
- `:guidance_scale` (float): Guidance scale (default: 0.0)
- `:output_format` (string): Output format "png", "jpg", "jpeg" (default: "png")

**Returns:**

- `{:ok, output_path}` - Successful generation with output file path
- `{:error, reason}` - Error with reason

**Example:**

```elixir
{:ok, image_path} = LivebookNx.ZImage.generate("a beautiful sunset", width: 1024, height: 1024)
```

##### `generate_batch(prompts, opts)`

Generates multiple images from a list of prompts.

**Parameters:**

- `prompts` ([string], required): List of text prompts
- `opts` (keyword list): Same options as `generate/2`

**Returns:**

- `{:ok, output_paths}` - List of successfully generated image paths
- `{:error, reason}` - Error message if batch generation failed

##### `queue_generation(prompt, opts)`

Queues an image generation job for asynchronous processing.

**Parameters:**

- Same as `generate/2`

**Returns:**

- `{:ok, job}` - Job queued successfully
- `{:error, changeset}` - Validation error

### LivebookNx.ZImage.Worker

Oban worker for asynchronous Z-Image-Turbo generation.

#### Configuration

```elixir
config :livebook_nx, Oban,
  queues: [
    default: 5,  # System jobs (maintenance, cleanup)
    ml: 8        # Shared computation queue (zimage, qwen3vl, etc.)
  ],
  repo: LivebookNx.Repo
```

The `ml` queue is shared across all computation tasks, allowing efficient resource utilization. The `default` queue handles system maintenance jobs.

### LivebookNx.Application

Application supervisor and startup logic.

#### Children

- `LivebookNx.Repo` - Database repository
- `Oban` - Background job processor
- `LivebookNx.Qwen3VL.Supervisor` - Inference supervisor

## Database Schema

### Inference

Represents an inference job.

**Fields:**

- `id` (integer, primary key): Unique identifier
- `image_path` (string): Path to input image
- `prompt` (string): Text prompt
- `response` (text): Model response
- `status` (string): Job status ("queued", "processing", "completed", "failed")
- `max_tokens` (integer): Maximum tokens
- `temperature` (float): Sampling temperature
- `top_p` (float): Top-p parameter
- `error_message` (text): Error details if failed
- `inserted_at` (datetime): Creation timestamp
- `updated_at` (datetime): Last update timestamp

**Example:**

```elixir
schema "inferences" do
  field :image_path, :string
  field :prompt, :string
  field :response, :string
  field :status, :string, default: "queued"
  field :max_tokens, :integer, default: 4096
  field :temperature, :float, default: 0.7
  field :top_p, :float, default: 0.9
  field :error_message, :string

  timestamps()
end
```

## CLI Tasks

### mix qwen3vl

Command-line interface for running inference.

**Usage:**

```bash
mix qwen3vl <image_path> <prompt> [options]
```

**Options:**

- `--max-tokens, -m INTEGER`: Maximum tokens (default: 4096)
- `--temperature, -t FLOAT`: Sampling temperature (default: 0.7)
- `--top-p FLOAT`: Top-p sampling (default: 0.9)
- `--output, -o PATH`: Output file path
- `--use-flash-attention`: Enable Flash Attention 2
- `--use-4bit`: Use 4-bit quantization (default: true)
- `--full-precision`: Use full precision

**Examples:**

```bash
# Basic usage
mix qwen3vl photo.jpg "Describe this image"

# With options
mix qwen3vl image.png "Analyze in detail" --max-tokens 500 --temperature 0.5 --output result.txt

# Full precision mode
mix qwen3vl diagram.jpg "Explain this technical diagram" --full-precision
```

### mix setup

Initializes the project and dependencies.

**Usage:**

```bash
mix setup
```

This task:

1. Installs Elixir dependencies
2. Sets up Python environment via Pythonx
3. Creates database if configured
4. Runs migrations

## Configuration Files

### config/config.exs

Compile-time configuration.

```elixir
import Config

config :livebook_nx,
  ecto_repos: [LivebookNx.Repo],
  generators: [timestamp_type: :utc_datetime]

config :livebook_nx,
  qwen3vl: %{
    model_id: "huihui-ai/Huihui-Qwen3-VL-4B-Instruct-abliterated",
    cache_dir: "priv/pretrained_weights"
  }

# Pythonx configuration
config :pythonx,
  python: ~S(python3),
  pip: ~S(uv pip),
  venv: ~S(.venv),
  requirements: ~S(pyproject.toml)
```

### config/runtime.exs

Runtime configuration for different environments.

```elixir
import Config

# Database configuration
if config_env() == :prod do
  config :livebook_nx, LivebookNx.Repo,
    username: System.get_env("DB_USERNAME"),
    password: System.get_env("DB_PASSWORD"),
    database: System.get_env("DB_NAME"),
    hostname: System.get_env("DB_HOST"),
    port: String.to_integer(System.get_env("DB_PORT") || "26257"),
    ssl: true
end

# Oban job queue configuration
config :livebook_nx, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 5, ml: 8],
  repo: LivebookNx.Repo
```

## Error Handling

### Common Error Types

#### Pythonx.Error

Python execution errors, typically from model inference.

**Handling:**

```elixir
try do
  LivebookNx.Qwen3VL.do_inference(config)
rescue
  e in Pythonx.Error ->
    Logger.error("Python error: #{inspect(e)}")
    {:error, :python_execution_failed}
end
```

#### Ecto Errors

Database operation failures.

**Handling:**

```elixir
case Repo.insert(changeset) do
  {:ok, record} -> {:ok, record}
  {:error, changeset} ->
    Logger.error("Database error: #{inspect(changeset.errors)}")
    {:error, :database_error}
end
```

#### File Errors

Image file access issues.

**Handling:**

```elixir
if File.exists?(image_path) do
  # Process image
else
  {:error, :image_not_found}
end
```

## Performance Considerations

### Memory Management

- Use 4-bit quantization to reduce VRAM usage
- Process images sequentially for large batches
- Monitor Python process memory usage

### Concurrency

- Use Oban for background job processing
- Configure appropriate pool sizes in database config
- Limit concurrent inference jobs based on hardware

### Caching

- Models are cached locally after first download
- Use database for job result caching
- Consider Redis for session data if needed

## Testing

### Unit Tests

```elixir
defmodule LivebookNx.Qwen3VLTest do
  use ExUnit.Case

  test "validates config correctly" do
    config = %{image_path: "test.jpg", prompt: "test"}
    assert :ok = Qwen3VL.validate_config(config)
  end
end
```

### Integration Tests

```elixir
test "runs inference end-to-end" do
  config = %{
    image_path: "test/fixtures/sample.jpg",
    prompt: "Describe this image",
    max_tokens: 50
  }

  assert {:ok, response} = Qwen3VL.do_inference(config)
  assert is_binary(response)
  assert String.length(response) > 0
end
```

## Migration Guide

### From v0.1.0 to v0.2.0

1. Update configuration structure in `config.exs`
2. Run database migrations for new schema
3. Update CLI usage (new options added)
4. Review Python environment setup

### Breaking Changes

- Configuration keys renamed for consistency
- Database schema changes require migration
- Pythonx version updated (check compatibility)
