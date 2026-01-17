# Forge API Reference

This document provides comprehensive technical documentation for the Zenoh-powered distributed AI platform Forge.

## Platform Components

### zimage (Python AI Service)

Location: `zimage/`
Technology: Python + Hugging Face Diffusers + Zenoh

**Service Interface:**
- **Transport**: HTTP/JSON via Zenoh bridge at `http://localhost:7447/apis/zimage/generate`
- **Data Format**: Standard JSON
- **Response**: Image paths in output directory with timestamps

**Local Development:**
```python
# Start service
cd zimage && uv run python inference_service.py

# Import inference function for testing
from inference_service import process_inference
result = process_inference("sunset mountain", 1024, 1024, 42, 4, 0.0, "png")
```

**Zenoh Integration:**
- **HTTP Bridge**: Accessible via `apis/zimage/**` endpoints
- **Liveliness Token**: "forge/services/zimage" (auto-announced)
- **Connection**: Bridges HTTP requests to internal Zenoh network

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

## API Access

The primary access method is via the **Zenoh HTTP Bridge**, which translates between HTTP requests and Zenoh messages. This enables universal access using any HTTP client.

### HTTP Bridge Endpoints

#### Image Generation
```bash
# Generate image via HTTP POST
curl -X POST http://localhost:7447/apis/zimage/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "sunset over mountains",
    "width": 1024,
    "height": 1024,
    "guidance_scale": 0.5,
    "num_steps": 4,
    "output_format": "png"
  }'
```

**Response:**
```json
{
  "status": "success",
  "output_path": "/tmp/generated/image_001.png",
  "metadata": {
    "model": "z-image-turbo",
    "inference_time": 2.3,
    "width": 1024,
    "height": 1024
  }
}
```

#### Batch Generation
```bash
curl -X POST http://localhost:7447/apis/zimage/batch \
  -H "Content-Type: application/json" \
  -d '[
    {"prompt": "cat", "width": 512, "height": 512},
    {"prompt": "dog", "width": 512, "height": 512}
  ]'
```

#### Service Status
```bash
# Get zimage service status
curl -X GET http://localhost:7447/apis/zimage/status
```

**Response Example:**
```json
{
  "service": "zimage",
  "status": "active",
  "version": "1.0.0",
  "uptime": 1234,
  "active_models": ["z-image-turbo"],
  "gpu_available": true
}
```

### Alternative: Zenoh Native (CLI)

For advanced usage, use the native Zenoh client:

```bash
# Generate with CLI (connects directly to Zenoh)
./zimage_client "sunset over mountains" --width 1024

# Service dashboard
./zimage_client --dashboard

# Batch processing
./zimage_client --batch "cat" "dog" "bird" --width 512
```

### Payload Format

All JSON payloads use this structure:

**Request:**
```json
{
  "prompt": "text description (required)",
  "width": 1024,
  "height": 1024,
  "num_steps": 4,
  "guidance_scale": 0.5,
  "output_format": "png|jpg|jpeg",
  "seed": "(optional integer)"
}
```

**Response:**
```json
{
  "status": "success|error",
  "output_path": "/path/to/image (if success)",
  "error": "error message (if failed)",
  "metadata": {
    "model": "model_name",
    "inference_time": 2.3,
    "width": 1024,
    "height": 1024,
    "gpu_memory_used": 2048
  }
}
```

### Compression

**HTTP compression is recommended and enabled.** Use gzip compression for large payloads:

```bash
curl -X POST http://localhost:7447/apis/zimage/generate \
  -H "Content-Type: application/json" \
  -H "Accept-Encoding: gzip,deflate" \
  --compressed \
  -d '{"prompt": "...very long prompt..."}'
```

This is particularly beneficial for complex AI prompts and batch operations.

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
- **Protocol**: Zenoh HTTP Bridge (REST API)
- **Serialization**: JSON with optional gzip compression
- **Compression**: HTTP gzip by default, recommended for AI payloads
- **Latency**: ~1-5ms local HTTP overhead on Zenoh network

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
