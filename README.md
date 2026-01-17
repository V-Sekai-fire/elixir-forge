# Forge

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Distributed AI platform with peer-to-peer networking via Zenoh. Generates images using Z-Image-Turbo model and provides real-time service monitoring.

## Components

- **zimage/**: Python AI service (Hugging Face diffusers + torch)
- **forge-client/**: Elixir CLI tools + live service dashboard
- **zenohd.service**: Systemd user service for Zenoh router daemon

## Quick Start

### 1. Install Zenoh Daemon
```bash
# Install basic Zenoh router
cargo install zenohd

# Verify installation
zenohd --version
```

### 2. Launch System
```bash
./boot_forge.sh  # Starts zenohd service + all components
```

### 3. Generate Images
Forge uses FlatBuffers over Zenoh native protocol for high-performance communication:

**Image Generation:**
```bash
# Generate AI images via FlatBuffers/Zenoh
./forge_client "sunset over mountains"

# Advanced options
./forge_client "cyberpunk city" --width 1024 --guidance-scale 0.5 --num-steps 8

# Batch processing
./forge_client --batch "cat in meadow" "dog by river" "bird in sky" --width 512
```

**Service Monitoring:**
```bash
# Real-time service dashboard
./forge_client --dashboard
```

### 4. Monitor Services
```bash
# Router status
systemctl --user status zenohd

# Service logs
journalctl --user -u zenohd --lines=10
```

## Architecture

```
[forge-client] ←→ [zenohd router] ←→ [zimage service]
  CLI/Dash         P2P Network          AI Generation
   (Elixir)           (systemd)             (Python)
```

- **Peer-to-Peer**: Services discover each other automatically
- **Binary Transport**: FlatBuffers for efficient data exchange
- **GPU Optimized**: torch.compile for 2x AI speedup on CUDA
- **Low Latency**: Sub-millisecond local communications

## Development

### Setup
```bash
# Clone repository
git clone https://github.com/V-Sekai-fire/forge.git
cd forge

# Setup Python AI service
cd zimage && uv sync

# Setup Elixir CLI tools
cd ../forge-client && mix deps.get && mix escript.build
```

### Runtime
- **Zenoh Router**: `systemctl --user start zenohd`
- **AI Service**: `cd zimage && uv run python inference_service.py`
- **Client Tools**: `cd forge-client && ./forge_client [command]`

### Zenohd Service Setup
For detailed zenohd systemd user service setup, see **ZENOHD_SERVICE_SETUP.md**

## Protocol

Forge communicates using **FlatBuffers binary serialization** over Zenoh's native protocol:

**Zenoh Keys:**
- `forge/inference/zimage` - AI generation queries
- `forge/services/zimage` - Service liveliness
- `forge/batch/zimage` - Batch processing

**Data Format:**
- **Requests**: FlatBuffers `InferenceRequest` schema
- **Responses**: FlatBuffers `InferenceResponse` schema
- **Transport**: Zenoh query(/get) primitives
- **Discovery**: Zenoh liveliness tokens

## Documentation

- **[Development Guide](CONTRIBUTING.md)** - Setup, guidelines, and contribution process
- **[Zenoh Integration](docs/proposals/zenoh-implementation.md)** - Technical architecture details
- **[API Reference](docs/api.md)** - Service interfaces and protocols

## License

MIT License - see [LICENSE](LICENSE)
