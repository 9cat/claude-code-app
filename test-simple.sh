#!/bin/bash

# Test the WebSocket proxy by simulating the mobile app behavior

echo "=== Testing Claude-Code WebSocket Proxy ==="
echo ""

# Test 1: Health check
echo "1. Testing health endpoint..."
HEALTH=$(curl -s http://localhost:64008/health)
echo "Health response: $HEALTH"
echo ""

# Test 2: Authentication endpoint  
echo "2. Testing auth endpoint..."
AUTH_RESPONSE=$(curl -s -X POST http://localhost:64008/auth \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}')
echo "Auth response: $AUTH_RESPONSE"
echo ""

# Test 3: Check if token was returned
TOKEN=$(echo $AUTH_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
if [ -n "$TOKEN" ]; then
    echo "✅ Authentication successful, token received"
else
    echo "❌ Authentication failed"
    exit 1
fi
echo ""

# Test 4: WebSocket connection (we'll check the logs for this)
echo "3. WebSocket test requires checking proxy logs after mobile app connects..."
echo "Check proxy.log for WebSocket connection and message handling"
echo ""

echo "=== Basic HTTP endpoints working! ==="
echo "To test WebSocket:"
echo "1. Use mobile app to connect to 192.168.2.178:64008"
echo "2. Login with admin/password123"  
echo "3. Send command: 'create hello world in go'"
echo "4. Check proxy.log for detailed logs"