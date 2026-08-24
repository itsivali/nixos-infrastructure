package api

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

// Mock implementations for testing

type mockDeploymentService struct {
	deployFunc  func(ctx context.Context, opts operations.DeployOpts) (*operations.DeploymentRecord, error)
	rollbackFunc func(ctx context.Context, opts operations.RollbackOpts) (*operations.RollbackResult, error)
	statusFunc  func(ctx context.Context) (*operations.DeploymentRecord, error)
	historyFunc func(ctx context.Context, limit int) ([]operations.DeploymentRecord, error)
}

func (m *mockDeploymentService) Deploy(ctx context.Context, opts operations.DeployOpts) (*operations.DeploymentRecord, error) {
	if m.deployFunc != nil {
		return m.deployFunc(ctx, opts)
	}
	return &operations.DeploymentRecord{
		ID:        "test-deploy-1",
		CommitSHA: "abc123",
		Actor:     "api",
		Source:    "web-ui",
		Timestamp: time.Now(),
		State:     operations.StateComplete,
		Status:    "deployed",
		Generation: 42,
	}, nil
}

func (m *mockDeploymentService) Rollback(ctx context.Context, opts operations.RollbackOpts) (*operations.RollbackResult, error) {
	if m.rollbackFunc != nil {
		return m.rollbackFunc(ctx, opts)
	}
	return &operations.RollbackResult{
		Success:      true,
		FromGen:      42,
		ToGen:        41,
		HealthPassed: true,
	}, nil
}

func (m *mockDeploymentService) Status(ctx context.Context) (*operations.DeploymentRecord, error) {
	if m.statusFunc != nil {
		return m.statusFunc(ctx)
	}
	return &operations.DeploymentRecord{
		Generation: 42,
		CommitSHA:  "abc123",
		State:      operations.StateComplete,
		Status:     "no deployment record",
		Timestamp:  time.Now(),
	}, nil
}

func (m *mockDeploymentService) History(ctx context.Context, limit int) ([]operations.DeploymentRecord, error) {
	if m.historyFunc != nil {
		return m.historyFunc(ctx, limit)
	}
	return []operations.DeploymentRecord{
		{ID: "deploy-1", CommitSHA: "abc123", State: operations.StateComplete},
		{ID: "deploy-2", CommitSHA: "def456", State: operations.StateComplete},
	}, nil
}

func (m *mockDeploymentService) AcquireLock(ctx context.Context) (func(), error) {
	return func() {}, nil
}

type mockHealthService struct {
	checkFunc func(ctx context.Context) (*operations.OverallHealth, error)
}

func (m *mockHealthService) Check(ctx context.Context) (*operations.OverallHealth, error) {
	if m.checkFunc != nil {
		return m.checkFunc(ctx)
	}
	return &operations.OverallHealth{
		Timestamp: time.Now(),
		Healthy:   true,
		Status:    "healthy",
		Components: map[string]operations.ComponentHealth{
			"systemd": {Name: "systemd", Healthy: true, Status: "running"},
		},
		NixOSGen:  42,
		GitCommit: "abc123",
	}, nil
}

func (m *mockHealthService) CheckComponent(ctx context.Context, name string) (*operations.ComponentHealth, error) {
	return &operations.ComponentHealth{Name: name, Healthy: true, Status: "ok"}, nil
}

type mockDriftService struct {
	detectFunc func(ctx context.Context) (*operations.DriftReport, error)
}

func (m *mockDriftService) Detect(ctx context.Context) (*operations.DriftReport, error) {
	if m.detectFunc != nil {
		return m.detectFunc(ctx)
	}
	return &operations.DriftReport{
		Timestamp:         time.Now(),
		GitDesiredCommit:  "abc123",
		GitDeployedCommit: "abc123",
		GitDrift:          false,
		GenExpected:       42,
		GenActive:         42,
		GenDrift:          false,
		ServicesDrift:     false,
		OverallDrift:      false,
	}, nil
}

type mockGenerationService struct {
	listFunc func(ctx context.Context) ([]operations.Generation, error)
}

func (m *mockGenerationService) List(ctx context.Context) ([]operations.Generation, error) {
	if m.listFunc != nil {
		return m.listFunc(ctx)
	}
	return []operations.Generation{
		{Number: 42, Date: time.Now(), Active: true},
		{Number: 41, Date: time.Now().AddDate(0, 0, -1), Active: false},
	}, nil
}

func (m *mockGenerationService) Current(ctx context.Context) (*operations.Generation, error) {
	return &operations.Generation{Number: 42, Date: time.Now(), Active: true}, nil
}

type mockServiceManager struct {
	restartFunc func(ctx context.Context, name string) error
}

func (m *mockServiceManager) List(ctx context.Context) ([]operations.ServiceStatus, error) {
	return []operations.ServiceStatus{
		{Name: "sshd.service", Active: "active", Running: true, Enabled: true},
		{Name: "tailscaled.service", Active: "active", Running: true, Enabled: true},
	}, nil
}

func (m *mockServiceManager) Status(ctx context.Context, name string) (*operations.ServiceStatus, error) {
	return &operations.ServiceStatus{Name: name, Active: "active", Running: true, Enabled: true}, nil
}

func (m *mockServiceManager) Restart(ctx context.Context, name string) error {
	if m.restartFunc != nil {
		return m.restartFunc(ctx, name)
	}
	return nil
}

type mockAuditLogger struct {
	logFunc   func(ctx context.Context, entry operations.AuditEntry) error
	queryFunc func(ctx context.Context, limit int, action string) ([]operations.AuditEntry, error)
}

func (m *mockAuditLogger) Log(ctx context.Context, entry operations.AuditEntry) error {
	if m.logFunc != nil {
		return m.logFunc(ctx, entry)
	}
	return nil
}

func (m *mockAuditLogger) Query(ctx context.Context, limit int, action string) ([]operations.AuditEntry, error) {
	if m.queryFunc != nil {
		return m.queryFunc(ctx, limit, action)
	}
	return []operations.AuditEntry{
		{Timestamp: time.Now(), Actor: "api", Action: "deploy", Result: "success"},
	}, nil
}

func TestAPIHandleHealth(t *testing.T) {
	server := &Server{
		health: &mockHealthService{},
	}

	req := httptest.NewRequest(http.MethodGet, "/api/health", nil)
	w := httptest.NewRecorder()

	server.handleHealth(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var health operations.OverallHealth
	if err := json.NewDecoder(w.Body).Decode(&health); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if !health.Healthy {
		t.Error("expected healthy = true")
	}
	if health.Status != "healthy" {
		t.Errorf("Status = %q, want %q", health.Status, "healthy")
	}
}

func TestAPIHandleHealthMethodNotAllowed(t *testing.T) {
	server := &Server{
		health: &mockHealthService{},
	}

	req := httptest.NewRequest(http.MethodPost, "/api/health", nil)
	w := httptest.NewRecorder()

	server.handleHealth(w, req)

	if w.Code != http.StatusMethodNotAllowed {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusMethodNotAllowed)
	}
}

func TestAPIHandleStatus(t *testing.T) {
	server := &Server{
		deployment: &mockDeploymentService{},
	}

	req := httptest.NewRequest(http.MethodGet, "/api/status", nil)
	w := httptest.NewRecorder()

	server.handleStatus(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var status operations.DeploymentRecord
	if err := json.NewDecoder(w.Body).Decode(&status); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if status.Generation != 42 {
		t.Errorf("Generation = %d, want 42", status.Generation)
	}
}

func TestAPIHandleDrift(t *testing.T) {
	server := &Server{
		drift: &mockDriftService{},
	}

	req := httptest.NewRequest(http.MethodGet, "/api/drift", nil)
	w := httptest.NewRecorder()

	server.handleDrift(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var report operations.DriftReport
	if err := json.NewDecoder(w.Body).Decode(&report); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if report.OverallDrift {
		t.Error("expected no drift")
	}
}

func TestAPIHandleDeploy(t *testing.T) {
	server := &Server{
		deployment: &mockDeploymentService{},
	}

	body := operations.DeployOpts{
		Commit: "abc123",
		Actor:  "web-ui",
		Source: "api",
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/deploy", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	server.handleDeploy(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var record operations.DeploymentRecord
	if err := json.NewDecoder(w.Body).Decode(&record); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if record.State != operations.StateComplete {
		t.Errorf("State = %q, want %q", record.State, operations.StateComplete)
	}
}

func TestAPIHandleDeployInvalidBody(t *testing.T) {
	server := &Server{
		deployment: &mockDeploymentService{},
	}

	req := httptest.NewRequest(http.MethodPost, "/api/deploy", bytes.NewReader([]byte("invalid")))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	server.handleDeploy(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

func TestAPIHandleRollback(t *testing.T) {
	server := &Server{
		deployment: &mockDeploymentService{},
	}

	body := operations.RollbackOpts{
		Generation: 0,
		Actor:      "operator",
		Reason:     "health check failed",
	}
	jsonBody, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/api/rollback", bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	server.handleRollback(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var result operations.RollbackResult
	if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if !result.Success {
		t.Error("expected Success = true")
	}
	if result.ToGen != 41 {
		t.Errorf("ToGen = %d, want 41", result.ToGen)
	}
}

func TestAPIHandleGenerations(t *testing.T) {
	server := &Server{
		generations: &mockGenerationService{},
	}

	req := httptest.NewRequest(http.MethodGet, "/api/generations", nil)
	w := httptest.NewRecorder()

	server.handleGenerations(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var gens []operations.Generation
	if err := json.NewDecoder(w.Body).Decode(&gens); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if len(gens) != 2 {
		t.Fatalf("expected 2 generations, got %d", len(gens))
	}
	if !gens[0].Active {
		t.Error("expected first generation to be active")
	}
}

func TestAPIHandleServices(t *testing.T) {
	server := &Server{
		services: &mockServiceManager{},
	}

	req := httptest.NewRequest(http.MethodGet, "/api/services", nil)
	w := httptest.NewRecorder()

	server.handleServices(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var services []operations.ServiceStatus
	if err := json.NewDecoder(w.Body).Decode(&services); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if len(services) != 2 {
		t.Fatalf("expected 2 services, got %d", len(services))
	}
}

func TestAPIHandleServiceRestart(t *testing.T) {
	server := &Server{
		services: &mockServiceManager{},
	}

	req := httptest.NewRequest(http.MethodPost, "/api/services/nginx.service/restart", nil)
	w := httptest.NewRecorder()

	server.handleServiceAction(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var result map[string]string
	if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if result["service"] != "nginx.service" {
		t.Errorf("service = %q, want %q", result["service"], "nginx.service")
	}
	if result["status"] != "restarted" {
		t.Errorf("status = %q, want %q", result["status"], "restarted")
	}
}

func TestAPIHandleServiceRestartError(t *testing.T) {
	server := &Server{
		services: &mockServiceManager{
			restartFunc: func(ctx context.Context, name string) error {
				return os.ErrPermission
			},
		},
	}

	req := httptest.NewRequest(http.MethodPost, "/api/services/nginx.service/restart", nil)
	w := httptest.NewRecorder()

	server.handleServiceAction(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusInternalServerError)
	}
}

func TestAPIHandleAudit(t *testing.T) {
	server := &Server{
		audit: &mockAuditLogger{},
	}

	req := httptest.NewRequest(http.MethodGet, "/api/audit?action=deploy", nil)
	w := httptest.NewRecorder()

	server.handleAudit(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var entries []operations.AuditEntry
	if err := json.NewDecoder(w.Body).Decode(&entries); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if len(entries) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(entries))
	}
	if entries[0].Action != "deploy" {
		t.Errorf("Action = %q, want %q", entries[0].Action, "deploy")
	}
}

func TestAPIHandleDeployments(t *testing.T) {
	server := &Server{
		deployment: &mockDeploymentService{},
	}

	req := httptest.NewRequest(http.MethodGet, "/api/deployments", nil)
	w := httptest.NewRecorder()

	server.handleDeployments(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	var history []operations.DeploymentRecord
	if err := json.NewDecoder(w.Body).Decode(&history); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if len(history) != 2 {
		t.Fatalf("expected 2 history entries, got %d", len(history))
	}
}

func TestAPIServerMethods(t *testing.T) {
	server := &Server{
		deployment:  &mockDeploymentService{},
		health:      &mockHealthService{},
		drift:       &mockDriftService{},
		generations: &mockGenerationService{},
		services:    &mockServiceManager{},
		audit:       &mockAuditLogger{},
	}

	tests := []struct {
		name   string
		method string
		path   string
		code   int
	}{
		{"health GET", http.MethodGet, "/api/health", http.StatusOK},
		{"health POST", http.MethodPost, "/api/health", http.StatusMethodNotAllowed},
		{"status GET", http.MethodGet, "/api/status", http.StatusOK},
		{"drift GET", http.MethodGet, "/api/drift", http.StatusOK},
		{"deploy POST", http.MethodPost, "/api/deploy", http.StatusOK},
		{"deploy GET", http.MethodGet, "/api/deploy", http.StatusMethodNotAllowed},
		{"rollback POST", http.MethodPost, "/api/rollback", http.StatusOK},
		{"rollback GET", http.MethodGet, "/api/rollback", http.StatusMethodNotAllowed},
		{"generations GET", http.MethodGet, "/api/generations", http.StatusOK},
		{"services GET", http.MethodGet, "/api/services", http.StatusOK},
		{"audit GET", http.MethodGet, "/api/audit", http.StatusOK},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var body *bytes.Reader
			if tt.method == http.MethodPost {
				jsonBody, _ := json.Marshal(map[string]string{})
				body = bytes.NewReader(jsonBody)
			} else {
				body = bytes.NewReader(nil)
			}

			req := httptest.NewRequest(tt.method, tt.path, body)
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			// Route to correct handler
			switch tt.path {
			case "/api/health":
				server.handleHealth(w, req)
			case "/api/status":
				server.handleStatus(w, req)
			case "/api/drift":
				server.handleDrift(w, req)
			case "/api/deploy":
				server.handleDeploy(w, req)
			case "/api/rollback":
				server.handleRollback(w, req)
			case "/api/generations":
				server.handleGenerations(w, req)
			case "/api/services":
				server.handleServices(w, req)
			case "/api/audit":
				server.handleAudit(w, req)
			}

			if w.Code != tt.code {
				t.Errorf("status code = %d, want %d", w.Code, tt.code)
			}
		})
	}
}

func TestAPIServerWriteJSON(t *testing.T) {
	server := &Server{}

	w := httptest.NewRecorder()
	server.writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}

	if w.Header().Get("Content-Type") != "application/json" {
		t.Errorf("Content-Type = %q, want %q", w.Header().Get("Content-Type"), "application/json")
	}
}

func TestAPIServerWriteError(t *testing.T) {
	server := &Server{}

	w := httptest.NewRecorder()
	server.writeError(w, http.StatusBadRequest, "invalid request")

	if w.Code != http.StatusBadRequest {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusBadRequest)
	}

	var errResp map[string]string
	if err := json.NewDecoder(w.Body).Decode(&errResp); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if errResp["error"] != "invalid request" {
		t.Errorf("error = %q, want %q", errResp["error"], "invalid request")
	}
}

func TestAPIServerLoggingMiddleware(t *testing.T) {
	server := &Server{}

	called := false
	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	})

	handler := server.loggingMiddleware(inner)

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if !called {
		t.Error("expected inner handler to be called")
	}
	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}
}

func TestAPIHandleDeployDefaultActorSource(t *testing.T) {
	server := &Server{
		deployment: &mockDeploymentService{
			deployFunc: func(ctx context.Context, opts operations.DeployOpts) (*operations.DeploymentRecord, error) {
				// Verify defaults are applied
				if opts.Actor != "api" {
					t.Errorf("Actor = %q, want %q", opts.Actor, "api")
				}
				if opts.Source != "web-ui" {
					t.Errorf("Source = %q, want %q", opts.Source, "web-ui")
				}
				return &operations.DeploymentRecord{
					ID:    "test",
					State: operations.StateComplete,
				}, nil
			},
		},
	}

	body := bytes.NewReader([]byte("{}"))
	req := httptest.NewRequest(http.MethodPost, "/api/deploy", body)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	server.handleDeploy(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}
}

func TestAPIHandleRollbackDefaultActor(t *testing.T) {
	server := &Server{
		deployment: &mockDeploymentService{
			rollbackFunc: func(ctx context.Context, opts operations.RollbackOpts) (*operations.RollbackResult, error) {
				if opts.Actor != "api" {
					t.Errorf("Actor = %q, want %q", opts.Actor, "api")
				}
				return &operations.RollbackResult{
					Success:      true,
					FromGen:      42,
					ToGen:        41,
					HealthPassed: true,
				}, nil
			},
		},
	}

	body := bytes.NewReader([]byte("{}"))
	req := httptest.NewRequest(http.MethodPost, "/api/rollback", body)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	server.handleRollback(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusOK)
	}
}

func TestAPIHandleDeployError(t *testing.T) {
	server := &Server{
		deployment: &mockDeploymentService{
			deployFunc: func(ctx context.Context, opts operations.DeployOpts) (*operations.DeploymentRecord, error) {
				return nil, os.ErrPermission
			},
		},
	}

	body := bytes.NewReader([]byte("{}"))
	req := httptest.NewRequest(http.MethodPost, "/api/deploy", body)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	server.handleDeploy(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusInternalServerError)
	}
}

func TestAPIHandleRollbackError(t *testing.T) {
	server := &Server{
		deployment: &mockDeploymentService{
			rollbackFunc: func(ctx context.Context, opts operations.RollbackOpts) (*operations.RollbackResult, error) {
				return &operations.RollbackResult{
					Success: false,
					Error:   "rollback failed",
				}, os.ErrPermission
			},
		},
	}

	body := bytes.NewReader([]byte("{}"))
	req := httptest.NewRequest(http.MethodPost, "/api/rollback", body)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	server.handleRollback(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("status code = %d, want %d", w.Code, http.StatusInternalServerError)
	}
}
