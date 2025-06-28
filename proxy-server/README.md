# Claude-Code Proxy Server (Go)

A high-performance WebSocket proxy server written in Go that provides secure access to Claude-Code CLI running in Docker containers.

## 🚀 Features

- **WebSocket Communication**: Real-time bidirectional communication
- **JWT Authentication**: Secure token-based authentication
- **Docker Integration**: Direct `docker exec` commands to Claude-Code container
- **Session Management**: Multi-user session handling
- **RESTful API**: HTTP endpoints for health checks and authentication
- **Graceful Shutdown**: Proper cleanup of all resources

## 🏗️ Architecture

```
Flutter App ←→ WebSocket ←→ Go Proxy Server ←→ Docker Exec ←→ Claude-Code CLI
```

## 🛠️ Installation

### Prerequisites
- Go 1.21 or higher
- Docker with claude-code container running
- Port 64008 available

### Build and Run
```bash
cd proxy-server
go mod tidy
go build -o claude-proxy main.go
./claude-proxy
```

### Development Mode
```bash
go run main.go
```

## 📡 API Endpoints

### HTTP Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server health check |
| POST | `/auth` | User authentication |
| GET | `/users` | List available users |
| GET | `/ws` | WebSocket upgrade |

### WebSocket Messages

#### Authentication
```json
{
  "type": "auth",
  "username": "admin",
  "password": "password123"
}
```

#### Execute Command
```json
{
  "type": "command",
  "command": "ls -la"
}
```

#### Start Claude Session
```json
{
  "type": "claude-start"
}
```

## 🔐 Authentication

### Default Users
| Username | Password |
|----------|----------|
| admin | password123 |
| developer | dev2024 |
| user | user123 |

### JWT Token
- **Algorithm**: HS256
- **Expiration**: 24 hours
- **Secret**: `claude-code-secret-2024` (hardcoded for demo)

## 🐳 Docker Integration

The proxy server interacts with the Claude-Code container using:
```bash
docker exec -i claude-code bash -c "your-command"
docker exec -it claude-code claude
```

### Container Requirements
- Container name: `claude-code`
- Must be running and accessible
- Claude CLI must be available in container

## 📱 Client Integration

### WebSocket Connection
```javascript
const ws = new WebSocket('ws://localhost:64008/ws');

// Authenticate
ws.send(JSON.stringify({
  type: 'auth',
  username: 'admin',
  password: 'password123'
}));

// Send command
ws.send(JSON.stringify({
  type: 'command',
  command: 'claude "Create a Python script"'
}));
```

### Flutter Integration
```dart
final channel = WebSocketChannel.connect(
  Uri.parse('ws://localhost:64008/ws'),
);

// Send authentication
channel.sink.add(jsonEncode({
  'type': 'auth',
  'username': 'admin',
  'password': 'password123',
}));
```

## 🔧 Configuration

### Environment Variables
```bash
# Optional: Override defaults
export CLAUDE_CONTAINER_NAME=my-claude-container
export JWT_SECRET=my-custom-secret
export SERVER_PORT=64008
```

### Hardcoded Configuration
Located in `main.go`:
```go
const (
    Port            = "64008"
    JWTSecret      = "claude-code-secret-2024"
    ClaudeContainer = "claude-code"
)
```

## 📊 Message Types

### Client → Server
- `auth`: Authentication request
- `command`: Execute shell command
- `claude-start`: Start Claude interactive session
- `ping`: Connection keepalive

### Server → Client
- `system`: System messages
- `auth-success`: Authentication successful
- `output`: Command output (stdout/stderr)
- `claude-output`: Claude session output
- `command-complete`: Command finished
- `claude-started`: Claude session started
- `claude-session-ended`: Claude session ended
- `error`: Error messages
- `pong`: Ping response

## 🚦 Health Monitoring

### Health Check
```bash
curl http://localhost:64008/health
```

Response:
```json
{
  "status": "healthy",
  "service": "claude-code-proxy",
  "timestamp": "2024-01-01T00:00:00Z",
  "container": "claude-code",
  "version": "1.0.0"
}
```

### Session Monitoring
- Active sessions tracked in memory
- Automatic cleanup on disconnect
- Process termination on session end

## 🛡️ Security Features

- **JWT-based authentication**
- **Input validation**
- **Process isolation**
- **Resource cleanup**
- **CORS protection**
- **Request timeout handling**

## 🐛 Troubleshooting

### Common Issues

1. **Container not found**
   ```bash
   docker ps | grep claude-code
   ```

2. **Port already in use**
   ```bash
   lsof -i :64008
   ```

3. **Permission denied**
   ```bash
   # Ensure user can access Docker
   docker ps
   ```

### Debug Logging
The server provides detailed logging for:
- WebSocket connections/disconnections
- Authentication attempts
- Command executions
- Error conditions

## 📈 Performance

- **Concurrent Sessions**: Unlimited (memory-bound)
- **Command Timeout**: 5 minutes default
- **WebSocket Keepalive**: Built-in ping/pong
- **Memory Usage**: Low footprint, efficient cleanup

## 🔄 Development

### Testing
```bash
# Unit tests
go test ./...

# Integration tests
go test -tags=integration ./...

# Load testing
# Use websocket testing tools
```

### Building for Production
```bash
# Linux
GOOS=linux GOARCH=amd64 go build -o claude-proxy-linux main.go

# Windows
GOOS=windows GOARCH=amd64 go build -o claude-proxy.exe main.go

# macOS
GOOS=darwin GOARCH=amd64 go build -o claude-proxy-macos main.go
```

---

**Ready to run:** `go run main.go` 🚀