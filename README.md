# Forge

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Distributed AI platform with peer-to-peer networking via Zenoh. Generates images using Z-Image-Turbo model and provides real-time service monitoring.

## Components

- **zimage/**: Python AI service (Hugging Face diffusers + torch)
- **zimage-client/**: Elixir CLI tools + live service dashboard
- **zenohd.service**: Systemd user service for Zenoh router daemon

## Quick Start

### 1. Install Zenoh Daemon
```bash
# Follow official installation guide:
# https://zenoh.io/docs/getting-started/installation/

# After installation, verify:
zenohd --version
```

### 2. Launch System
```bash
./boot_forge.sh  # Starts all components: router + services + dashboard
```

### 3. Generate Images
```bash
# Simple generation
./zimage_client "sunset over mountains"

# Advanced options
./zimage_client "cyberpunk city" --width 1024 --height 1024 --guidance-scale 0.5

# Batch processing
./zimage_client --batch "cat" "dog" "bird"

# Monitor services
./zimage_client --dashboard
```

## Architecture

```
[zimage-client] ←→ [zenohd router] ←→ [zimage service]
  CLI/Dash           P2P Network          AI Generation
   (Elixir)            (systemd)             (Python)
```

- **Peer-to-Peer**: Services discover each other automatically
- **Binary Transport**: FlatBuffers for efficient data exchange
- **GPU Optimized**: torch.compile for 2x AI speedup on CUDA

## Development

### Setup
```bash
# Clone repository
git clone https://github.com/V-Sekai-fire/forge.git
cd forge

# Setup Python AI service
cd zimage && uv sync

# Setup Elixir tools
cd ../zimage-client && mix deps.get && mix escript.build
```

### Runtime
- **Zenoh Router**: `systemctl --user start zenohd`
- **AI Service**: `cd zimage && uv run python inference_service.py`
- **Client Tools**: `cd zimage-client && ./zimage_client [command]`

### Zenohd Service Setup
For detailed zenohd systemd user service setup, see **ZENOHD_SERVICE_SETUP.md**

## Documentation

- **[Development Guide](CONTRIBUTING.md)** - Setup, guidelines, and contribution process
- **[Zenoh Integration](docs/proposals/zenoh-implementation.md)** - Technical architecture details
- **[API Reference](docs/api.md)** - Service interfaces and protocols

## License

MIT License - see [LICENSE](LICENSE)
