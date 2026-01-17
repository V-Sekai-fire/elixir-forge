#!/bin/bash
# Test Zenoh end-to-end integration

echo "Testing Zenoh integration..."

# Install required packages if needed
pip install zenoh flatbuffers flexbuffers || echo "Dependencies may need installation"

echo "Starting zimage Python service in background..."
cd zimage
python inference_service.py &
PID=$!

sleep 2

echo "Starting zimage-client dashboard..."
cd ../zimage-client
mix escript.build
./zimage_client --dashboard &
CLIENT_PID=$!

sleep 5

echo "Testing client request..."
timeout 10 ./zimage_client "test prompt" --timeout 5

echo "Cleaning up..."
kill $PID $CLIENT_PID

echo "End-to-end test completed."
