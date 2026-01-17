# Zimage

Python-based image generation service using Zenoh for peer-to-peer inference.

## Installation

```bash
pip install zenoh aiohttp numpy torch  # depending on model requirements
pip install flatbuffers
```

## Setup FlatBuffers

Install the FlatBuffers compiler (flatc), then generate Python modules:

```bash
# Install flatc (if not already)
# On Ubuntu: apt install flatbuffers-compiler
# On macOS: brew install flatbuffers

cd zimage
flatc --python flatbuffers/inference_request.fbs flatbuffers/inference_response.fbs

# This generates flatbuffers/inference_request.py and flatbuffers/inference_response.py
```

Then uncomment the imports in `inference_service.py`:

```python
from flatbuffers import inference_request, inference_response
```

## Running

```bash
cd zimage
python inference_service.py
```

## FlatBuffers Schemas

The service uses FlatBuffers for efficient serialization:
- `flatbuffers/inference_request.fbs`: Request format
- `flatbuffers/inference_response.fbs`: Response format

## Architecture

- Connects via Zenoh for P2P discovery
- Provides queryable endpoint at "forge/inference/qwen"
- Uses liveliness tokens for service announcement
- Integrates with AI models (placeholder in code)
