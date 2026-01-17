# ZimageClient

A Zenoh client for requesting image generation from Zimage services and monitoring the Forge fabric.

## Installation

```bash
cd zimage-client
mix deps.get
mix escript.build
```

## Usage

### Command Line

```bash
# Single image generation
./zimage_client "a beautiful sunset"

# With custom options
./zimage_client "a cat wearing a hat" --width 512 --height 512 --seed 42

# Batch generation
./zimage_client --batch "cat" "dog" "bird" --width 256

# Launch service dashboard
./zimage_client --dashboard
```

### Elixir API

```elixir
# Start the client
ZimageClient.Application.start(:normal, [])

# Generate single image
{:ok, path} = ZimageClient.Client.generate("a beautiful landscape")

# Generate with options
{:ok, path} = ZimageClient.Client.generate("fantasy castle", width: 1024, height: 768, seed: 123)

# Batch generation
{:ok, results} = ZimageClient.Client.generate_batch(["sunset", "mountain", "forest"])

# Check service availability
:ok = ZimageClient.Client.ping()
```

## Requirements

- Zimage service running with Zenoh
- Network connectivity to Zenoh peers

## Options

- `--width`, `-w`: Image width (64-2048)
- `--height`, `-h`: Image height (64-2048)
- `--seed`, `-s`: Random seed (0 for random)
- `--num-steps`: Inference steps (default: 4)
- `--guidance-scale`: Guidance scale (default: 0.0)
- `--output-format`: png, jpg, jpeg (default: png)
- `--batch`, `-b`: Process multiple prompts
- `--dashboard`, `-d`: Launch service dashboard to monitor active AI services
- `--help`: Show help

## Architecture

The client uses Zenoh's peer-to-peer discovery to automatically find and connect to Zimage services. Requests are sent as query-reply messages with parameters encoded as strings.
