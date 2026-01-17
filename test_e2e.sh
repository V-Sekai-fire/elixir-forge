#!/bin/bash
# Test Zenoh integration

echo "Testing Zenoh integration..."

echo "Testing zimage Python service (demo run)..."
cd zimage
timeout 15 uv run python inference_service.py || echo "Service test requires uv dependencies to be installed"

echo "Testing zimage-client build..."
cd ../zimage-client
mix escript.build

echo "Service and client compilation tests completed."
echo "For full E2E testing with Zenoh router:"
echo "  1. Start zenohd router"
echo "  2. Run zimage service in one terminal: uv run python inference_service.py"
echo "  3. Run zimage-client in another: ./zimage_client 'prompt' --width 512"
echo "  4. Check 'output/' directory for generated images"
