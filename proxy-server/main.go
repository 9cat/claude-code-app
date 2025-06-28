package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
)

// Configuration constants
const (
	Port            = "64008"
	JWTSecret      = "claude-code-secret-2024"
	ClaudeContainer = "claude-code"
)

// Hardcoded users for simple authentication
var Users = map[string]string{
	"admin":     "password123",
	"developer": "dev2024",
	"user":      "user123",
}

// Message types for WebSocket communication
type WSMessage struct {
	Type      string `json:"type"`
	Message   string `json:"message,omitempty"`
	Command   string `json:"command,omitempty"`
	Data      string `json:"data,omitempty"`
	Username  string `json:"username,omitempty"`
	Password  string `json:"password,omitempty"`
	Token     string `json:"token,omitempty"`
	SessionID string `json:"sessionId,omitempty"`
	Source    string `json:"source,omitempty"`
	ExitCode  int    `json:"exitCode,omitempty"`
	Timestamp string `json:"timestamp,omitempty"`
	User      string `json:"user,omitempty"`
}

// JWT Claims structure
type Claims struct {
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// Session management
type Session struct {
	ID            string
	WebSocket     *websocket.Conn
	Authenticated bool
	Username      string
	Process       *exec.Cmd
	ClaudeStdin   io.WriteCloser
	StartTime     time.Time
	mutex         sync.Mutex
	claudeStarted bool
}

var (
	sessions = make(map[string]*Session)
	upgrader = websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool {
			return true // Allow connections from any origin for now
		},
	}
	sessionsMutex sync.RWMutex
)

// HTTP handlers
func healthHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"service":   "claude-code-proxy",
		"timestamp": time.Now().Format(time.RFC3339),
		"container": ClaudeContainer,
		"version":   "1.0.0",
	})
}

func authHandler(c *gin.Context) {
	var req struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request format",
		})
		return
	}

	if Users[req.Username] == req.Password {
		// Generate JWT token
		claims := &Claims{
			Username: req.Username,
			RegisteredClaims: jwt.RegisteredClaims{
				ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
				IssuedAt:  jwt.NewNumericDate(time.Now()),
			},
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		tokenString, err := token.SignedString([]byte(JWTSecret))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"success": false,
				"message": "Token generation failed",
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"token":   tokenString,
			"message": "Authentication successful",
			"user":    req.Username,
		})
	} else {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"message": "Invalid credentials",
		})
	}
}

func usersHandler(c *gin.Context) {
	usernames := make([]string, 0, len(Users))
	for username := range Users {
		usernames = append(usernames, username)
	}

	c.JSON(http.StatusOK, gin.H{
		"users": usernames,
		"note":  "Use any of these usernames with their respective passwords",
	})
}

// WebSocket handler
func wsHandler(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	sessionID := generateSessionID()
	session := &Session{
		ID:           sessionID,
		WebSocket:    conn,
		Authenticated: false,
		StartTime:    time.Now(),
	}

	sessionsMutex.Lock()
	sessions[sessionID] = session
	sessionsMutex.Unlock()

	log.Printf("[%s] New WebSocket connection from %s", sessionID, c.ClientIP())

	// Send welcome message
	welcomeMsg := WSMessage{
		Type:      "system",
		Message:   "Welcome to Claude-Code Proxy Server! Please authenticate first.",
		SessionID: sessionID,
		Timestamp: time.Now().Format(time.RFC3339),
	}
	session.sendMessage(welcomeMsg)

	// Handle messages in main loop (not background)
	session.handleMessages()

	// Cleanup on disconnect
	log.Printf("[%s] WebSocket disconnected", sessionID)
	session.cleanup()
	sessionsMutex.Lock()
	delete(sessions, sessionID)
	sessionsMutex.Unlock()
}

// Session methods
func (s *Session) sendMessage(msg WSMessage) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	if err := s.WebSocket.WriteJSON(msg); err != nil {
		log.Printf("[%s] Error sending message: %v", s.ID, err)
	}
}

func (s *Session) sendError(message string) {
	s.sendMessage(WSMessage{
		Type:      "error",
		Message:   message,
		Timestamp: time.Now().Format(time.RFC3339),
	})
}

func (s *Session) handleMessages() {
	for {
		messageType, message, err := s.WebSocket.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[%s] WebSocket error: %v", s.ID, err)
			}
			break
		}

		// Handle ping/pong for keep-alive
		if messageType == websocket.PingMessage {
			if err := s.WebSocket.WriteMessage(websocket.PongMessage, nil); err != nil {
				log.Printf("[%s] Error sending pong: %v", s.ID, err)
				break
			}
			continue
		}

		// Log received messages for debugging
		log.Printf("[%s] Received message type %d, length %d: %s", s.ID, messageType, len(message), string(message))

		// Only process text messages
		if messageType != websocket.TextMessage {
			continue
		}

		// Parse JSON message
		var msg WSMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("[%s] Error parsing JSON: %v", s.ID, err)
			s.sendError("Invalid JSON message")
			continue
		}

		log.Printf("[%s] Parsed message: type=%s, auth=%v", s.ID, msg.Type, s.Authenticated)

		switch msg.Type {
		case "auth":
			s.handleAuth(msg)
		case "command":
			if s.Authenticated {
				s.sendToClaudeSession(msg.Command)
			} else {
				s.sendError("Authentication required")
			}
		case "claude-start":
			if s.Authenticated {
				s.startPersistentClaudeSession()
			} else {
				s.sendError("Authentication required")
			}
		case "ping":
			s.sendMessage(WSMessage{
				Type:      "pong",
				Timestamp: time.Now().Format(time.RFC3339),
			})
		default:
			s.sendError(fmt.Sprintf("Unknown message type: %s", msg.Type))
		}
	}
}

func (s *Session) handleAuth(msg WSMessage) {
	log.Printf("[%s] Auth attempt: username=%s, hasToken=%v", s.ID, msg.Username, msg.Token != "")

	if msg.Token != "" {
		// Verify existing token
		token, err := jwt.ParseWithClaims(msg.Token, &Claims{}, func(token *jwt.Token) (interface{}, error) {
			return []byte(JWTSecret), nil
		})

		if err != nil {
			log.Printf("[%s] Token verification failed: %v", s.ID, err)
			s.sendError("Invalid token")
			return
		}

		if claims, ok := token.Claims.(*Claims); ok && token.Valid {
			s.Username = claims.Username
			s.Authenticated = true
			log.Printf("[%s] Token auth successful for user: %s", s.ID, s.Username)
			s.sendMessage(WSMessage{
				Type:    "auth-success",
				Message: fmt.Sprintf("Welcome back, %s!", s.Username),
				User:    s.Username,
			})
		} else {
			log.Printf("[%s] Token validation failed", s.ID)
			s.sendError("Token validation failed")
		}
	} else if msg.Username != "" && msg.Password != "" {
		// Direct username/password auth
		log.Printf("[%s] Password auth attempt for user: %s", s.ID, msg.Username)
		
		if Users[msg.Username] == msg.Password {
			s.Username = msg.Username
			s.Authenticated = true

			// Generate new token
			claims := &Claims{
				Username: msg.Username,
				RegisteredClaims: jwt.RegisteredClaims{
					ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
					IssuedAt:  jwt.NewNumericDate(time.Now()),
				},
			}

			token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
			tokenString, _ := token.SignedString([]byte(JWTSecret))

			log.Printf("[%s] Password auth successful for user: %s", s.ID, s.Username)
			s.sendMessage(WSMessage{
				Type:    "auth-success",
				Message: fmt.Sprintf("Authentication successful! Welcome, %s", s.Username),
				Token:   tokenString,
				User:    s.Username,
			})
			
			// Automatically start Claude session after authentication
			go func() {
				time.Sleep(1 * time.Second) // Give UI time to process auth success
				s.startPersistentClaudeSession()
			}()
		} else {
			log.Printf("[%s] Invalid credentials for user: %s", s.ID, msg.Username)
			s.sendError("Invalid credentials")
		}
	} else {
		log.Printf("[%s] Missing auth data", s.ID)
		s.sendError("Missing authentication data")
	}
}

// Start persistent Claude session that remembers conversation
func (s *Session) startPersistentClaudeSession() {
	if s.claudeStarted {
		log.Printf("[%s] Claude session already running", s.ID)
		return
	}

	log.Printf("[%s] Starting persistent Claude interactive session", s.ID)

	s.killProcess()

	// Start interactive bash session in current container (we're already in claude-code container)
	s.Process = exec.Command("bash")

	stdin, err := s.Process.StdinPipe()
	if err != nil {
		s.sendError(fmt.Sprintf("Failed to create stdin pipe: %v", err))
		return
	}
	s.ClaudeStdin = stdin

	stdout, err := s.Process.StdoutPipe()
	if err != nil {
		s.sendError(fmt.Sprintf("Failed to create stdout pipe: %v", err))
		return
	}

	stderr, err := s.Process.StderrPipe()
	if err != nil {
		s.sendError(fmt.Sprintf("Failed to create stderr pipe: %v", err))
		return
	}

	if err := s.Process.Start(); err != nil {
		s.sendError(fmt.Sprintf("Failed to start Claude session: %v", err))
		return
	}

	s.claudeStarted = true

	// Handle stdout - continuous output from Claude
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			output := scanner.Text()
			log.Printf("[%s] Claude stdout: %s", s.ID, output)
			s.sendMessage(WSMessage{
				Type:   "claude-output",
				Data:   output,
				Source: "claude",
			})
		}
		log.Printf("[%s] Claude stdout closed", s.ID)
	}()

	// Handle stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			output := scanner.Text()
			log.Printf("[%s] Claude stderr: %s", s.ID, output)
			s.sendMessage(WSMessage{
				Type:   "claude-output",
				Data:   output,
				Source: "claude-error",
			})
		}
		log.Printf("[%s] Claude stderr closed", s.ID)
	}()

	// Send initial message and start Claude-Code CLI
	s.sendMessage(WSMessage{
		Type:    "claude-started",
		Message: "🚀 Claude-Code CLI session started! Ready for project development.",
	})

	// Auto-start Claude-Code CLI in the bash session after a short delay
	go func() {
		time.Sleep(1 * time.Second)
		log.Printf("[%s] Auto-starting Claude-Code CLI in bash session", s.ID)
		
		// Send environment setup and claude command
		commands := []string{
			"cd /app",  // Go to the app directory
			"export TERM=xterm-256color",  // Set terminal type
			"claude",   // Start Claude-Code CLI
		}
		
		for _, cmd := range commands {
			_, err := s.ClaudeStdin.Write([]byte(cmd + "\n"))
			if err != nil {
				log.Printf("[%s] Error sending command '%s': %v", s.ID, cmd, err)
				return
			}
			time.Sleep(500 * time.Millisecond)  // Small delay between commands
		}
	}()

	// Wait for process completion
	go func() {
		err := s.Process.Wait()
		exitCode := 0
		if err != nil {
			if exitError, ok := err.(*exec.ExitError); ok {
				exitCode = exitError.ExitCode()
			}
		}

		log.Printf("[%s] Claude session ended with exit code: %d", s.ID, exitCode)
		s.claudeStarted = false
		s.ClaudeStdin = nil
		s.Process = nil

		s.sendMessage(WSMessage{
			Type:     "claude-session-ended",
			ExitCode: exitCode,
			Message:  "Claude-Code CLI session ended. Development history preserved.",
		})
	}()
}

// Send command to existing Claude-Code CLI session
func (s *Session) sendToClaudeSession(command string) {
	if command == "" {
		s.sendError("No command provided")
		return
	}

	// Start Claude-Code session if not already running
	if !s.claudeStarted {
		s.startPersistentClaudeSession()
		// Wait a bit for Claude-Code CLI to start
		time.Sleep(3 * time.Second)
	}

	if s.ClaudeStdin == nil {
		s.sendError("Claude-Code CLI session not available")
		return
	}

	log.Printf("[%s] Sending to Claude-Code CLI: %s", s.ID, command)

	// Echo the command to UI first (like terminal behavior)
	s.sendMessage(WSMessage{
		Type:   "user-input",
		Data:   "➤ " + command,
		Source: "user",
	})

	// Send command to Claude-Code CLI
	_, err := s.ClaudeStdin.Write([]byte(command + "\n"))
	if err != nil {
		log.Printf("[%s] Error writing to Claude-Code CLI stdin: %v", s.ID, err)
		s.sendError(fmt.Sprintf("Failed to send command to Claude-Code CLI: %v", err))
		
		// Try to restart the session
		s.claudeStarted = false
		go func() {
			time.Sleep(1 * time.Second)
			s.startPersistentClaudeSession()
		}()
		return
	}
}

func (s *Session) killProcess() {
	if s.ClaudeStdin != nil {
		s.ClaudeStdin.Close()
		s.ClaudeStdin = nil
	}
	if s.Process != nil && s.Process.Process != nil {
		s.Process.Process.Kill()
		s.Process = nil
	}
	s.claudeStarted = false
}

func (s *Session) cleanup() {
	log.Printf("[%s] Cleaning up session", s.ID)
	s.killProcess()
	if s.WebSocket != nil {
		s.WebSocket.Close()
	}
}

// Utility functions
func generateSessionID() string {
	return fmt.Sprintf("session_%d", time.Now().UnixNano())
}

func main() {
	// Set Gin mode
	gin.SetMode(gin.ReleaseMode)

	// Create Gin router
	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// Add CORS middleware
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Routes
	r.GET("/health", healthHandler)
	r.POST("/auth", authHandler)
	r.GET("/users", usersHandler)
	r.GET("/ws", wsHandler)

	// Start server
	srv := &http.Server{
		Addr:    ":" + Port,
		Handler: r,
	}

	// Graceful shutdown
	go func() {
		sigint := make(chan os.Signal, 1)
		signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
		<-sigint

		log.Println("\n🛑 Shutting down proxy server...")

		// Close all active sessions
		sessionsMutex.RLock()
		for _, session := range sessions {
			session.cleanup()
		}
		sessionsMutex.RUnlock()

		// Shutdown server
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := srv.Shutdown(ctx); err != nil {
			log.Printf("Server shutdown error: %v", err)
		}

		log.Println("✅ Proxy server shut down gracefully")
	}()

	// Start server
	log.Printf("🚀 Claude-Code Proxy Server starting on port %s", Port)
	log.Printf("📡 WebSocket endpoint: ws://localhost:%s/ws", Port)
	log.Printf("🔗 Health check: http://localhost:%s/health", Port)
	log.Printf("🔐 Auth endpoint: http://localhost:%s/auth", Port)
	log.Printf("👥 Available users: http://localhost:%s/users", Port)
	log.Printf("🐳 Target container: %s", ClaudeContainer)

	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server failed to start: %v", err)
	}
}