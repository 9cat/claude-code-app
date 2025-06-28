package main

import (
	"bufio"
	"context"
	"fmt"
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
	ID           string
	WebSocket    *websocket.Conn
	Authenticated bool
	Username     string
	Process      *exec.Cmd
	StartTime    time.Time
	mutex        sync.Mutex
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

	// Handle messages
	go session.handleMessages()

	// Cleanup on disconnect
	defer func() {
		log.Printf("[%s] WebSocket disconnected", sessionID)
		session.cleanup()
		sessionsMutex.Lock()
		delete(sessions, sessionID)
		sessionsMutex.Unlock()
	}()

	// Keep connection alive
	for {
		_, _, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[%s] WebSocket error: %v", sessionID, err)
			}
			break
		}
	}
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
		var msg WSMessage
		err := s.WebSocket.ReadJSON(&msg)
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("[%s] Message read error: %v", s.ID, err)
			}
			break
		}

		switch msg.Type {
		case "auth":
			s.handleAuth(msg)
		case "command":
			if s.Authenticated {
				s.handleCommand(msg)
			} else {
				s.sendError("Authentication required")
			}
		case "claude-start":
			if s.Authenticated {
				s.startClaudeSession()
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
	if msg.Token != "" {
		// Verify existing token
		token, err := jwt.ParseWithClaims(msg.Token, &Claims{}, func(token *jwt.Token) (interface{}, error) {
			return []byte(JWTSecret), nil
		})

		if err != nil {
			s.sendError("Invalid token")
			return
		}

		if claims, ok := token.Claims.(*Claims); ok && token.Valid {
			s.Username = claims.Username
			s.Authenticated = true
			s.sendMessage(WSMessage{
				Type:    "auth-success",
				Message: fmt.Sprintf("Welcome back, %s!", s.Username),
				User:    s.Username,
			})
		} else {
			s.sendError("Token validation failed")
		}
	} else if msg.Username != "" && msg.Password != "" {
		// Direct username/password auth
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

			s.sendMessage(WSMessage{
				Type:    "auth-success",
				Message: fmt.Sprintf("Authentication successful! Welcome, %s", s.Username),
				Token:   tokenString,
				User:    s.Username,
			})
		} else {
			s.sendError("Invalid credentials")
		}
	} else {
		s.sendError("Missing authentication data")
	}
}

func (s *Session) handleCommand(msg WSMessage) {
	command := msg.Command
	if command == "" {
		command = msg.Data
	}
	if command == "" {
		s.sendError("No command provided")
		return
	}

	log.Printf("[%s] Executing command: %s", s.ID, command)

	// Kill existing process if any
	s.killProcess()

	// Execute command in Claude-Code container
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	s.Process = exec.CommandContext(ctx, "docker", "exec", "-i", ClaudeContainer, "bash", "-c", command)

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
		s.sendError(fmt.Sprintf("Failed to start command: %v", err))
		return
	}

	// Handle stdout
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			s.sendMessage(WSMessage{
				Type:   "output",
				Data:   scanner.Text(),
				Source: "stdout",
			})
		}
	}()

	// Handle stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			s.sendMessage(WSMessage{
				Type:   "output",
				Data:   scanner.Text(),
				Source: "stderr",
			})
		}
	}()

	// Wait for completion
	go func() {
		err := s.Process.Wait()
		exitCode := 0
		if err != nil {
			if exitError, ok := err.(*exec.ExitError); ok {
				exitCode = exitError.ExitCode()
			}
		}

		s.sendMessage(WSMessage{
			Type:     "command-complete",
			ExitCode: exitCode,
			Message:  fmt.Sprintf("Command completed with exit code: %d", exitCode),
		})

		s.Process = nil
	}()
}

func (s *Session) startClaudeSession() {
	log.Printf("[%s] Starting Claude interactive session", s.ID)

	s.killProcess()

	// Start interactive Claude session
	ctx := context.Background()
	s.Process = exec.CommandContext(ctx, "docker", "exec", "-it", ClaudeContainer, "claude")

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

	// Handle stdout
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			s.sendMessage(WSMessage{
				Type:   "claude-output",
				Data:   scanner.Text(),
				Source: "claude",
			})
		}
	}()

	// Handle stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			s.sendMessage(WSMessage{
				Type:   "claude-output",
				Data:   scanner.Text(),
				Source: "claude-error",
			})
		}
	}()

	// Send initial message
	s.sendMessage(WSMessage{
		Type:    "claude-started",
		Message: "Claude interactive session started",
	})

	// Wait for completion
	go func() {
		err := s.Process.Wait()
		exitCode := 0
		if err != nil {
			if exitError, ok := err.(*exec.ExitError); ok {
				exitCode = exitError.ExitCode()
			}
		}

		s.sendMessage(WSMessage{
			Type:     "claude-session-ended",
			ExitCode: exitCode,
			Message:  "Claude session ended",
		})

		s.Process = nil
	}()
}

func (s *Session) killProcess() {
	if s.Process != nil && s.Process.Process != nil {
		s.Process.Process.Kill()
		s.Process = nil
	}
}

func (s *Session) cleanup() {
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