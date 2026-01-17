# ZenohRouter

Elixir application for managing Zenoh router daemon in the Forge distributed AI platform.

## Overview

ZenohRouter provides a dedicated CLI for starting, stopping, and monitoring the Zenoh router daemon (`zenohd`) that enables peer-to-peer communication between AI services in the Forge platform.

## Installation

### Prerequisites
- Elixir 1.19+
- Zenoh router daemon (`zenohd`):

```bash
# Rust/Cargo installation (recommended):
cargo install zenohd

# ⚰️ DEPRECATED: macOS Homebrew method broken (2026-01-16)
# brew tap eclipse-zenoh/homebrew-eclipse-zenohd
# brew install eclipse-zenohd

# Or download pre-built binaries from https://zenoh.io/download/
```

### Building the CLI
```bash
cd zenoh-router
mix deps.get
mix escript.build
```

This creates the executable: `zenoh_router`

## Usage

### Start Router (Default Command)
```bash
./zenoh_router start
# Starts router on port 7447 with default configuration
```

### Custom Configuration
```bash
# Custom port
./zenoh_router start --port 8080

# With config file
./zenoh_router start --config router.yaml
```

### Router Management
```bash
# Check status and health
./zenoh_router status

# Stop all router processes
./zenoh_router stop

# Show logs (if available)
./zenoh_router logs

# Show help
./zenoh_router --help
```

## Router Configuration

The CLI automatically configures zenohd with:
- **TCP Listener**: `tcp/[::]:PORT` - Zenoh protocol communications
- **WebSocket Support**: Enables web browser connections
- **REST API**: Monitoring at `http://localhost:PORT/@config`
- **Admin Space**: Management operations at `zenohd/**`

For advanced configuration, create a zenohd config file:

```yaml
# router.yaml
listen: tcp/[::]:7447
plugins:
  rest: {}
  storage: {}
```

## Integration with Forge Services

### Zimage (Python AI Service)
Zimage connects to the router for distributed AI inference:
```bash
cd zimage
uv sync
uv run python inference_service.py  # Uses localhost:7447 router
```

### Zimage-Client (Elixir Tools)
Client discovers services through the router:
```bash
cd zimage-client
mix escript.build
./zimage_client "generate this" --width 1024
```

## Architecture

```
[Zenoh Router] <--TCP/WS--> [zimage AI Service]
     ^
     |                  <--FlatBuffers/Zenoh-->
[REST API / Admin]  -->  [zimage-client CLI]
```

Benefits:
- **Zero-Configuration**: Services auto-discover via router
- **Scalability**: Multiple AI services can join the network
- **Monitoring**: Built-in REST API for status/health checks
- **Cross-Language**: Works with Python, Elixir, and other Zenoh clients

## Development

Run tests:
```bash
mix test
```

Format code:
```bash
mix format
```

## Troubleshooting

### Router Won't Start
```bash
# Check if zenohd is installed
which zenohd

# Check for port conflicts
lsof -i :7447
```

### Connection Issues
```bash
# Verify router status
./zenoh_router status

# Check firewall settings
# Ensure port 7447 is open for TCP
```

### Logs Not Available
zenohd logs location depends on OS:
- **Default**: `/tmp/zenohd.log` (or stdout if foreground)
- **System service**: `journalctl -u zenohd`
- **Docker**: `docker logs zenohd-container`

## License

MIT License - see Forge project LICENSE file.
