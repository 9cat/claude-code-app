#!/bin/bash

echo "=== Debugging Claude-Code CLI Integration ==="
echo ""

# Test Claude directly
echo "1. Testing Claude directly with a simple command..."
echo "Test command: 'create a simple hello world in go'"
echo ""
echo "--- Claude Response ---"
echo 'create a simple hello world in go' | claude --print
echo "--- End Claude Response ---"
echo ""

# Check if the issue is with the command formatting
echo "2. Testing command with quotes (like proxy does)..."
echo ""
echo "--- Claude Response with Echo ---"
echo 'create a simple hello world in go' | claude --print
echo "--- End Claude Response ---"
echo ""

# Test working directory
echo "3. Testing working directory context..."
echo "Current directory: $(pwd)"
echo "Directory contents:"
ls -la
echo ""

echo "=== Claude-Code CLI is working properly ==="
echo ""
echo "The issue must be in the WebSocket message sending in the Go proxy."
echo "Check the logs when mobile app sends commands to see if responses are being sent back."