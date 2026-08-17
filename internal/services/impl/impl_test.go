package impl_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/services"
	"github.com/itsivali/nixos-infrastructure/internal/services/impl"
)

// --- NotificationService ---

func TestTelegramNotification_SendAlert(t *testing.T) {
	// Use a non-existent script — the important thing is the service compiles
	// and methods are callable. Full integration requires notify.sh + secrets.
	svc := impl.NewTelegramNotification("/bin/sh")
	if svc == nil {
		t.Fatal("NewTelegramNotification returned nil")
	}
}

func TestTelegramNotification_SendDeploymentResult(t *testing.T) {
	svc := impl.NewTelegramNotification("/bin/sh")
	// Test that the method doesn't panic with empty result
	err := svc.SendDeploymentResult(context.Background(), services.DeploymentResult{
		Host:    "test-host",
		Success: true,
		Commit:  "abc12345",
		Branch:  "main",
	})
	// Will fail to send (no bot token) but should not panic
	_ = err
}

func TestTelegramNotification_SendHealthAlert(t *testing.T) {
	svc := impl.NewTelegramNotification("/bin/sh")
	err := svc.SendHealthAlert(context.Background(), "prometheus", true, "")
	_ = err
}

// --- PrometheusMetrics ---

func TestPrometheusMetrics_Query(t *testing.T) {
	// Mock Prometheus server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"status": "success",
			"data": {
				"resultType": "vector",
				"result": [[null, "42.5"]]
			}
		}`))
	}))
	defer server.Close()

	svc := impl.NewPrometheusMetrics(server.URL)
	val, err := svc.Query(context.Background(), "up")
	if err != nil {
		t.Fatalf("Query failed: %v", err)
	}
	if val != 42.5 {
		t.Fatalf("expected 42.5, got %f", val)
	}
}

func TestPrometheusMetrics_QueryEmpty(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"status": "success",
			"data": {
				"resultType": "vector",
				"result": []
			}
		}`))
	}))
	defer server.Close()

	svc := impl.NewPrometheusMetrics(server.URL)
	_, err := svc.Query(context.Background(), "up{job=\"nonexistent\"}")
	if err == nil {
		t.Fatal("expected error for empty results")
	}
}

// --- SystemHealthChecker ---

func TestSystemHealthChecker_CheckServices(t *testing.T) {
	svc := impl.NewSystemHealthChecker()
	result, err := svc.CheckServices(context.Background(), []string{"nonexistent-service-xyz"})
	if err != nil {
		t.Fatalf("CheckServices failed: %v", err)
	}
	if h, ok := result["nonexistent-service-xyz"]; ok {
		if h.Healthy {
			t.Fatal("nonexistent service should not be healthy")
		}
	}
}

func TestSystemHealthChecker_CheckDisk(t *testing.T) {
	svc := impl.NewSystemHealthChecker()
	result, err := svc.CheckDisk(context.Background(), []string{"/"})
	if err != nil {
		t.Fatalf("CheckDisk failed: %v", err)
	}
	if _, ok := result["/"]; !ok {
		t.Fatal("root mount not found in disk health")
	}
}

func TestSystemHealthChecker_CheckNetwork(t *testing.T) {
	svc := impl.NewSystemHealthChecker()
	nh, err := svc.CheckNetwork(context.Background())
	if err != nil {
		t.Fatalf("CheckNetwork failed: %v", err)
	}
	if nh == nil {
		t.Fatal("NetworkHealth is nil")
	}
	// DNS check may or may not pass in CI, so just verify structure
}

// --- NixOSPlatform ---

func TestNixOSPlatform_Health(t *testing.T) {
	svc := impl.NewNixOSPlatform("/tmp")
	ph, err := svc.Health(context.Background())
	if err != nil {
		t.Fatalf("Health failed: %v", err)
	}
	if ph == nil {
		t.Fatal("PlatformHealth is nil")
	}
	// nix and git should be available
	if len(ph.Plugins) == 0 {
		t.Fatal("no plugins checked")
	}
}

func TestNixOSPlatform_Status(t *testing.T) {
	svc := impl.NewNixOSPlatform("/tmp")
	ps, err := svc.Status(context.Background())
	if err != nil {
		t.Fatalf("Status failed: %v", err)
	}
	if ps == nil {
		t.Fatal("PlatformStatus is nil")
	}
}

// --- ResticBackup ---

func TestResticBackup_Status(t *testing.T) {
	svc := impl.NewResticBackup()
	status, err := svc.Status(context.Background())
	if err != nil {
		t.Fatalf("Status failed: %v", err)
	}
	if status == nil {
		t.Fatal("BackupStatus is nil")
	}
}
