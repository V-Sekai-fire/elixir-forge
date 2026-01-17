# Forge API Reference

This document provides comprehensive technical documentation for the Zenoh-powered distributed AI platform Forge.

## Platform Components

### zimage (Python AI Service)

Location: `zimage/`
Technology: Python + Hugging Face Diffusers + Zenoh

**Service Interface:**
- **Transport**: Zenoh queryable at "zimage/generate/**"
- **Data Format**: FlatBuffers with FlexBuffers extensions
- **Response**: Image paths in output directory with timestamps

**Local Development:**
```python
# Start service
cd zimage && uv run python inference_service.py

# Import inference function
from inference_service import process_inference
result = process_inference("sunset mountain", 1024, 1024, 42, 4, 0.0, "png")
```

**Zenoh Integration:**
- Liveliness token: "forge/services/qwen3vl"
- Connection: Auto-discovers via zenoh-router

### zimage-client (Elixir CLI Tools)

Location: `zimage-client/`
Technology: Elixir with Zenoh connectivity

**CLI Interface:**
```bash
cd zimage-client
./zimage_client "generate this" --width 1024 --guidance-scale 0.5
./zimage_client --dashboard  # Real-time monitoring
./zimage_client --router     # Start zenohd
```

**Commands:**
- **generate**: Send image generation request via Zenoh
- **batch**: Generate multiple images
- **dashboard**: Live service monitoring
- **router**: Manage zenohd process

### zenoh-router (Router Management)

Location: `zenoh-router/`
Technology: Elixir process management + zenohd

**CLI Interface:**
```bash
cd zenoh-router
./zenoh_router start                 # Launch daemon
./zenoh_router status               # Health check
./zenoh_router stop                 # Graceful shutdown
./zenoh_router logs                 # View daemon output
```

**Zenohd Configuration:**
- TCP listener: `:7447`
- WebSocket: Enabled for browser connections
- REST API: `http://localhost:7447/@config`

## Access Patterns

### Option 1: HTTP Bridge (Universal)

If zenohd has REST plugin enabled (`--rest-http-port`):

```bash
# Generate image via HTTP
curl -X POST http://localhost:7447/apis/zimage/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "sunset over mountains",
    "width": 1024,
    "height": 1024,
    "guidance_scale": 0.5
  }'

# Response: JSON with image path
{
  "status": "success",
  "output_path": "/path/to/generated/image.png",
  "metadata": {
    "model": "z-image-turbo",
    "inference_time": 2.3
  }
}

# Query service status
GET http://localhost:7447/apis/zimage/status

# List available services
GET http://localhost:7447/apis/discovery/services
```

### Option 2: Zenoh Native (High Performance)

Direct Zenoh protocol access (FlatBuffers):

#### Service Discovery
- **URI Pattern**: `forge/services/[service_name]`
- **Liveliness**: Automatic service announcement
- **Querying**: `forge/inference/[model]`

#### Message Schemas

**Request Schema (FlatBuffers):**
```fbs
table InferenceRequest {
  prompt: string;
  width: int32 = 1024;
  height: int32 = 1024;
  seed: int32;
  num_steps: int32 = 4;
  guidance_scale: float;
  output_format: string;
}

table FlexMetadata {
  // GlTF2 extension fields for flexibility
  extensions_and_extras: [ubyte];
}
```

**Response Schema (FlatBuffers):**
```fbs
table InferenceResponse {
  // Binary image data (when available)
  result_data: [ubyte];
  // Flexible extensions for metadata
  extensions: [ubyte];
}
```

**Extension Metadata (FlexBuffers):**
```json
{
  "status": "success",
  "output_path": "/path/to/generated/image.png",
  "error": "failure description",
  "metadata": {
    "model": "z-image-turbo",
    "inference_time": 2.3,
    "gpu_memory_used": 2048
  }
}
```

## Error Codes

### Zenoh Network Errors
- `E0001`: Router not found
- `E0002`: Service unreachable
- `E0003`: Network timeout

### AI Service Errors
- `A0001`: Invalid prompt
- `A0002`: Image generation failed
- `A0003`: GPU memory exceeded

### Configuration Errors
- `C0001`: Zenohd not installed
- `C0002`: Dependencies missing

## Configuration

### Environment Variables
```bash
# Zenoh configuration
ZENOH_CONFIG=config.json

# AI model paths
FORGE_MODEL_PATH=./pretrained_weights

# Service ports
ROUTER_PORT=7447
```

### Default Configurations
```yaml
# zenohd.yml
listen:
  - tcp/[::]:7447
plugins:
  rest:
  ws:
```

## Performance Metrics

### AI Generation
- **Model**: Z-Image-Turbo (optimized diffusers)
- **GPU Acceleration**: torch.compile + CUDA
- **Memory**: ~2-4GB VRAM for 1024x1024 images
- **Speed**: ~2-5 seconds per image

### Network Transport
- **Protocol**: Zenoh with automatic routing
- **Serialization**: FlatBuffers (zero-copy)
- **Compression**: Built-in Zenoh optimization
- **Latency**: Sub-millisecond local, <10ms LAN

## Testing

### Unit Tests
```bash
# Python
cd zimage && uv run pytest

# Elixir
cd zimage-client && mix test
cd zenoh-router && mix test
```

### Integration Tests
```bash
# Automated system test
./test_e2e.sh

# Manual component testing
zenohd &
./zenoh-router/zenoh_router status
./zimage_client --dashboard
```

## Troubleshooting

### Common Issues

**Zenohd not found:**
```
Install with: cargo install zenohd
Or download pre-built binaries from zenoh.io/download
```

**Services not connecting:**
```
Ensure zenohd is running: ./zenoh-router/zenoh_router status
Check firewall: ports 7447, TCP
```

**AI generation slow/export:**
```
Verify CUDA: python -c "import torch; print(torch.cuda.is_available())"
Check VRAM: ~4GB free needed
Update drivers if issues
```

### Logs and Debugging

**Service Logs:**
- Zenoh router: `./zenoh-router/zenoh_router logs`
- AI service: Run in foreground for stdout

**Zenoh Health:**
```bash
curl http://localhost:7447/@config/status
```

**Network Debugging:**
```bash
zenohd --debug  # Verbose networking
