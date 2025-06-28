# 🔍 Debug Steps - Finding the WebSocket Issue

## Current Status
✅ **WebSocket Proxy Working**: Logs show Claude responds and proxy sends messages successfully  
❌ **Flutter UI Not Showing Responses**: User sees no feedback in the mobile app UI  

## Test Pages Available (Docker External Access)
1. **HTML WebSocket Test**: http://192.168.2.178:63980/test-websocket-debug.html
2. **Flutter Mimic Test**: http://192.168.2.178:63980/flutter-mimic-test.html  
3. **Flutter App**: http://192.168.2.178:64007

⚠️ **Docker Context**: Port 8080 inside container → Port 63980 externally

## Step-by-Step Debug Process

### Step 1: Test HTML WebSocket (Independent Verification)
```
1. Open: http://192.168.2.178:63980/test-websocket-debug.html
2. Click "Connect" → Should see "Connected ✅"
3. Click "Authenticate" → Should see auth success message
4. Click "Send Test Command" → Should see Claude response in green
5. Watch console for detailed WebSocket logs
```

**Expected Result**: If this works, WebSocket proxy is 100% confirmed working.

### Step 2: Monitor Proxy Logs During Test
```bash
# In terminal, watch real-time logs:
tail -f /app/claude-code-app/proxy-server/proxy.log

# Look for these patterns when testing:
# - "New WebSocket connection from..."
# - "Successfully sent message type=claude-output"  
# - "Sent Claude response to WebSocket client"
```

### Step 3: Test Flutter App with Browser DevTools
```
1. Open: http://192.168.2.178:64007
2. Open browser DevTools (F12) → Console tab
3. Connect and authenticate in Flutter app
4. Send test command
5. Check console for debug logs:
   - "📨 WebSocketService: Raw data received"
   - "🎯 WebSocketService: Parsed JSON"  
   - "📨 Received WebSocket message"
   - "✅ Adding message to UI"
```

### Step 4: Compare Behavior
- **HTML Test Works + Flutter Doesn't**: Issue is in Flutter WebSocket handling
- **HTML Test Fails**: Issue is in WebSocket proxy itself
- **Both Fail**: Issue is network/connectivity

## Key Debug Points

### WebSocket Proxy Logs (Working ✅)
```
Successfully sent message type=claude-output
Sent Claude response to WebSocket client
```

### Flutter Debug Logs (To Check)
Should see in browser console:
```
📨 WebSocketService: Raw data received: {"type":"claude-output","data":"..."}
🎯 WebSocketService: Parsed JSON: {type: "claude-output", data: "..."}
📨 Received WebSocket message: {type: "claude-output", data: "..."}
✅ Adding message to UI: type=assistant, content="..."
```

### Common Issues to Check
1. **WebSocket URL**: Flutter might be connecting to wrong URL
2. **Message Parsing**: JSON format differences
3. **UI Update**: Message added but UI not refreshing
4. **Build Issue**: Old Flutter build without debug code

## Next Steps
1. Test HTML page first to confirm proxy works independently
2. Check Flutter browser console for debug logs
3. Compare message formats between working/non-working tests
4. Identify exact point where messages are lost in Flutter app