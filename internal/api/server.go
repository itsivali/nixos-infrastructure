package api

import (
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

// Server is the internal operations API server.
type Server struct {
	addr        string
	repoDir     string
	deployment  operations.DeploymentService
	health      operations.HealthService
	drift       operations.DriftService
	generations operations.GenerationService
	services    operations.ServiceManager
	audit       operations.AuditLogger

	// Security
	apiToken      string
	secondaryToken string
	allowedOrigins []string
	rateLimiter    *rateLimiter
}

// Config holds the API server configuration.
type Config struct {
	Addr           string
	RepoDir        string
	APIToken       string
	SecondaryToken string
	AllowedOrigins []string
}

// rateLimiter provides token-bucket rate limiting per IP
type rateLimiter struct {
	mu       sync.Mutex
	clients  map[string]*bucket
	rate     int
	capacity int
}

type bucket struct {
	tokens   int
	lastTime time.Time
}

func newRateLimiter(rate, capacity int) *rateLimiter {
	return &rateLimiter{
		clients:  make(map[string]*bucket),
		rate:     rate,
		capacity: capacity,
	}
}

func (rl *rateLimiter) allow(key string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	b, exists := rl.clients[key]
	if !exists {
		rl.clients[key] = &bucket{tokens: rl.capacity - 1, lastTime: now}
		return true
	}

	// Refill tokens based on elapsed time
	elapsed := now.Sub(b.lastTime).Seconds()
	b.tokens += int(elapsed * float64(rl.rate))
	if b.tokens > rl.capacity {
		b.tokens = rl.capacity
	}
	b.lastTime = now

	if b.tokens <= 0 {
		return false
	}
	b.tokens--
	return true
}

// ServiceRestartAllowlist is the list of services that can be restarted via API
var ServiceRestartAllowlist = map[string]bool{
	"operations-web-ui.service":    true,
	"nginx.service":               true,
	"prometheus.service":          true,
	"grafana-server.service":      true,
	"loki.service":                true,
	"alertmanager.service":        true,
	"deployment-health.timer":     true,
	"gitops-reconciler.timer":     true,
	"restic-backup.timer":         true,
	"sshd.service":                true,
	"tailscaled.service":          true,
	"NetworkManager.service":      true,
}

// Valid service name pattern (alphanumeric, hyphens, underscores, dots, @ for template units)
var validServiceName = regexp.MustCompile(`^[a-zA-Z0-9_\-\.@]+\.service$|^timer$`)

// NewServer creates a new API server.
func NewServer(cfg Config) *Server {
	audit := operations.NewAuditLogger()
	deploy := operations.NewDeploymentService(cfg.RepoDir, audit)

	allowedOrigins := cfg.AllowedOrigins
	if len(allowedOrigins) == 0 {
		allowedOrigins = []string{"http://127.0.0.1:8080"}
	}

	return &Server{
		addr:          cfg.Addr,
		repoDir:       cfg.RepoDir,
		deployment:    deploy,
		health:        operations.NewHealthService(cfg.RepoDir),
		drift:         operations.NewDriftService(cfg.RepoDir),
		generations:   operations.NewGenerationService(),
		services:      operations.NewServiceManager(),
		audit:         audit,
		apiToken:      cfg.APIToken,
		secondaryToken: cfg.SecondaryToken,
		allowedOrigins: allowedOrigins,
		rateLimiter:   newRateLimiter(10, 100), // 10 req/s, burst of 100
	}
}

// Start starts the API server.
func (s *Server) Start() error {
	mux := http.NewServeMux()

	// Health endpoints (no auth required)
	mux.HandleFunc("/api/health", s.handleHealth)

	// Authenticated endpoints
	mux.HandleFunc("/api/status", s.requireAuth(s.handleStatus))
	mux.HandleFunc("/api/drift", s.requireAuth(s.handleDrift))
	mux.HandleFunc("/api/deployments", s.requireAuth(s.handleDeployments))
	mux.HandleFunc("/api/deployments/latest", s.requireAuth(s.handleLatestDeployment))
	mux.HandleFunc("/api/deploy", s.requireAuth(s.handleDeploy))
	mux.HandleFunc("/api/rollback", s.requireAuth(s.handleRollback))
	mux.HandleFunc("/api/generations", s.requireAuth(s.handleGenerations))
	mux.HandleFunc("/api/services", s.requireAuth(s.handleServices))
	mux.HandleFunc("/api/services/", s.requireAuth(s.handleServiceAction))
	mux.HandleFunc("/api/audit", s.requireAuth(s.handleAudit))

	// Middleware chain: rate limit -> CORS -> logging
	handler := s.rateLimitMiddleware(s.corsMiddleware(s.loggingMiddleware(mux)))

	srv := &http.Server{
		Addr:         s.addr,
		Handler:      handler,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	log.Printf("Operations API listening on %s", s.addr)
	return srv.ListenAndServe()
}

// requireAuth wraps a handler with HMAC-SHA256 Bearer token authentication
func (s *Server) requireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Skip auth if no token configured (development mode)
		if s.apiToken == "" {
			next(w, r)
			return
		}

		auth := r.Header.Get("Authorization")
		if auth == "" {
			s.auditAuthFailure(r, "missing authorization header")
			s.writeError(w, http.StatusUnauthorized, "authorization required")
			return
		}

		if !strings.HasPrefix(auth, "Bearer ") {
			s.auditAuthFailure(r, "invalid authorization format")
			s.writeError(w, http.StatusUnauthorized, "invalid authorization format")
			return
		}

		token := strings.TrimPrefix(auth, "Bearer ")

		// Check primary token
		primaryMatch := subtle.ConstantTimeCompare([]byte(token), []byte(s.apiToken)) == 1
		// Check secondary token (rotation grace period)
		secondaryMatch := s.secondaryToken != "" && subtle.ConstantTimeCompare([]byte(token), []byte(s.secondaryToken)) == 1

		if !primaryMatch && !secondaryMatch {
			s.auditAuthFailure(r, "invalid token")
			s.writeError(w, http.StatusUnauthorized, "invalid token")
			return
		}

		next(w, r)
	}
}

// auditAuthFailure logs authentication failures
func (s *Server) auditAuthFailure(r *http.Request, reason string) {
	if s.audit != nil {
		s.audit.Log(r.Context(), operations.AuditEntry{
			Timestamp: time.Now(),
			Actor:     "api-auth",
			Action:    "auth_failure",
			Target:    r.URL.Path,
			Source:    "api",
			Result:    "failed",
			Error:     fmt.Sprintf("%s from %s", reason, r.RemoteAddr),
		})
	}
}

// validateServiceName checks if a service name is valid and in the allowlist
func validateServiceName(name string) error {
	// Clean the name
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("empty service name")
	}

	// Check for path traversal
	if strings.Contains(name, "..") || strings.Contains(name, "/") {
		return fmt.Errorf("invalid service name: path traversal detected")
	}

	// Check format
	if !validServiceName.MatchString(name) {
		return fmt.Errorf("invalid service name format: %s", name)
	}

	// Check allowlist
	if !ServiceRestartAllowlist[name] {
		return fmt.Errorf("service %s is not in the restart allowlist", name)
	}

	return nil
}

// extractServiceName extracts and validates service name from URL path
func extractServiceName(path string) (string, error) {
	// Expected format: /api/services/{name}/restart
	prefix := "/api/services/"
	suffix := "/restart"

	if !strings.HasPrefix(path, prefix) || !strings.HasSuffix(path, suffix) {
		return "", fmt.Errorf("invalid service action path: %s", path)
	}

	name := path[len(prefix) : len(path)-len(suffix)]
	return name, validateServiceName(name)
}

func (s *Server) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		duration := time.Since(start)
		log.Printf("%s %s %s", r.Method, r.URL.Path, duration)
	})
}

// corsMiddleware handles CORS with origin validation
func (s *Server) corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")

		// Check if origin is allowed
		allowed := false
		for _, o := range s.allowedOrigins {
			if origin == o {
				allowed = true
				break
			}
		}

		if allowed {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
			w.Header().Set("Access-Control-Max-Age", "86400")
		}

		// Handle preflight
		if r.Method == http.MethodOptions {
			if !allowed {
				w.WriteHeader(http.StatusForbidden)
				return
			}
			w.WriteHeader(http.StatusNoContent)
			return
		}

		if !allowed && origin != "" {
			w.WriteHeader(http.StatusForbidden)
			json.NewEncoder(w).Encode(map[string]string{"error": "origin not allowed"})
			return
		}

		next.ServeHTTP(w, r)
	})
}

// rateLimitMiddleware applies rate limiting per client IP
func (s *Server) rateLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip rate limiting for health endpoint
		if r.URL.Path == "/api/health" {
			next.ServeHTTP(w, r)
			return
		}

		clientIP := r.RemoteAddr
		if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
			clientIP = strings.Split(forwarded, ",")[0]
		}

		if !s.rateLimiter.allow(clientIP) {
			w.Header().Set("Retry-After", "1")
			s.writeError(w, http.StatusTooManyRequests, "rate limit exceeded")
			return
		}

		next.ServeHTTP(w, r)
	})
}

// RequestSizeLimit limits request body size
const RequestSizeLimit = 1 << 20 // 1MB

func (s *Server) writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func (s *Server) writeError(w http.ResponseWriter, status int, message string) {
	s.writeJSON(w, status, map[string]string{"error": message})
}

// Handlers

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, 405, "method not allowed")
		return
	}

	health, err := s.health.Check(r.Context())
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("health check failed: %v", err))
		return
	}

	s.writeJSON(w, 200, health)
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, 405, "method not allowed")
		return
	}

	status, err := s.deployment.Status(r.Context())
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("status failed: %v", err))
		return
	}

	s.writeJSON(w, 200, status)
}

func (s *Server) handleDrift(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, 405, "method not allowed")
		return
	}

	report, err := s.drift.Detect(r.Context())
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("drift detection failed: %v", err))
		return
	}

	s.writeJSON(w, 200, report)
}

func (s *Server) handleDeployments(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, 405, "method not allowed")
		return
	}

	history, err := s.deployment.History(r.Context(), 20)
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("history failed: %v", err))
		return
	}

	s.writeJSON(w, 200, history)
}

func (s *Server) handleLatestDeployment(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, 405, "method not allowed")
		return
	}

	status, err := s.deployment.Status(r.Context())
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("status failed: %v", err))
		return
	}

	s.writeJSON(w, 200, status)
}

func (s *Server) handleDeploy(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, 405, "method not allowed")
		return
	}

	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, RequestSizeLimit)

	var opts operations.DeployOpts
	if err := json.NewDecoder(r.Body).Decode(&opts); err != nil {
		s.writeError(w, 400, "invalid request body")
		return
	}

	// Server-derived actor identity (never trust client-supplied actor)
	opts.Actor = "api"
	if opts.Source == "" {
		opts.Source = "web-ui"
	}

	record, err := s.deployment.Deploy(r.Context(), opts)
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("deploy failed: %v", err))
		return
	}

	s.writeJSON(w, 200, record)
}

func (s *Server) handleRollback(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		s.writeError(w, 405, "method not allowed")
		return
	}

	// Limit request body size
	r.Body = http.MaxBytesReader(w, r.Body, RequestSizeLimit)

	var opts operations.RollbackOpts
	if err := json.NewDecoder(r.Body).Decode(&opts); err != nil {
		s.writeError(w, 400, "invalid request body")
		return
	}

	// Server-derived actor identity
	opts.Actor = "api"

	result, err := s.deployment.Rollback(r.Context(), opts)
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("rollback failed: %v", err))
		return
	}

	s.writeJSON(w, 200, result)
}

func (s *Server) handleGenerations(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, 405, "method not allowed")
		return
	}

	generations, err := s.generations.List(r.Context())
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("list generations failed: %v", err))
		return
	}

	s.writeJSON(w, 200, generations)
}

func (s *Server) handleServices(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, 405, "method not allowed")
		return
	}

	services, err := s.services.List(r.Context())
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("list services failed: %v", err))
		return
	}

	s.writeJSON(w, 200, services)
}

func (s *Server) handleServiceAction(w http.ResponseWriter, r *http.Request) {
	// Extract and validate service name from path: /api/services/{name}/restart
	name, err := extractServiceName(r.URL.Path)
	if err != nil {
		s.writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if r.Method != http.MethodPost {
		s.writeError(w, 405, "method not allowed")
		return
	}

	if err := s.services.Restart(r.Context(), name); err != nil {
		s.writeError(w, 500, fmt.Sprintf("restart failed: %v", err))
		return
	}

	s.writeJSON(w, 200, map[string]string{"status": "restarted", "service": name})
}

func (s *Server) handleAudit(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.writeError(w, 405, "method not allowed")
		return
	}

	action := r.URL.Query().Get("action")
	entries, err := s.audit.Query(r.Context(), 50, action)
	if err != nil {
		s.writeError(w, 500, fmt.Sprintf("query audit failed: %v", err))
		return
	}

	s.writeJSON(w, 200, entries)
}
