package api

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

// Server is the internal operations API server.
type Server struct {
	addr       string
	repoDir    string
	deployment operations.DeploymentService
	health     operations.HealthService
	drift      operations.DriftService
	generations operations.GenerationService
	services   operations.ServiceManager
	audit      operations.AuditLogger
}

// Config holds the API server configuration.
type Config struct {
	Addr    string
	RepoDir string
}

// NewServer creates a new API server.
func NewServer(cfg Config) *Server {
	audit := operations.NewAuditLogger()
	deploy := operations.NewDeploymentService(cfg.RepoDir, audit)

	return &Server{
		addr:        cfg.Addr,
		repoDir:     cfg.RepoDir,
		deployment:  deploy,
		health:      operations.NewHealthService(cfg.RepoDir),
		drift:       operations.NewDriftService(cfg.RepoDir),
		generations: operations.NewGenerationService(),
		services:    operations.NewServiceManager(),
		audit:       audit,
	}
}

// Start starts the API server.
func (s *Server) Start() error {
	mux := http.NewServeMux()

	// Health endpoints
	mux.HandleFunc("/api/health", s.handleHealth)
	mux.HandleFunc("/api/status", s.handleStatus)
	mux.HandleFunc("/api/drift", s.handleDrift)

	// Deployment endpoints
	mux.HandleFunc("/api/deployments", s.handleDeployments)
	mux.HandleFunc("/api/deployments/latest", s.handleLatestDeployment)
	mux.HandleFunc("/api/deploy", s.handleDeploy)
	mux.HandleFunc("/api/rollback", s.handleRollback)

	// Generation endpoints
	mux.HandleFunc("/api/generations", s.handleGenerations)

	// Service endpoints
	mux.HandleFunc("/api/services", s.handleServices)
	mux.HandleFunc("/api/services/", s.handleServiceAction)

	// Audit endpoints
	mux.HandleFunc("/api/audit", s.handleAudit)

	// Logging middleware
	handler := s.loggingMiddleware(mux)

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

func (s *Server) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		duration := time.Since(start)
		log.Printf("%s %s %s", r.Method, r.URL.Path, duration)
	})
}

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

	var opts operations.DeployOpts
	if err := json.NewDecoder(r.Body).Decode(&opts); err != nil {
		s.writeError(w, 400, "invalid request body")
		return
	}

	if opts.Actor == "" {
		opts.Actor = "api"
	}
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

	var opts operations.RollbackOpts
	if err := json.NewDecoder(r.Body).Decode(&opts); err != nil {
		s.writeError(w, 400, "invalid request body")
		return
	}

	if opts.Actor == "" {
		opts.Actor = "api"
	}

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
	// Extract service name from path: /api/services/{name}/restart
	name := r.URL.Path[len("/api/services/"):]
	name = name[:len(name)-len("/restart")]

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
