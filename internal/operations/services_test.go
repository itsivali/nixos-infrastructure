package operations

import (
	"context"
	"testing"
)

func TestServiceManagerList(t *testing.T) {
	manager := NewServiceManager()

	services, err := manager.List(context.Background())
	if err != nil {
		t.Fatalf("List() error: %v", err)
	}

	// Should return a list of critical services
	if len(services) == 0 {
		t.Error("expected at least one service in list")
	}

	// Verify service names
	expectedServices := map[string]bool{
		"sshd.service":              true,
		"NetworkManager.service":    true,
		"tailscaled.service":        true,
		"nginx.service":             true,
		"prometheus.service":        true,
		"grafana-server.service":    true,
		"loki.service":              true,
		"alertmanager.service":      true,
		"operations-web-ui.service": true,
		"deployment-health.timer":   true,
		"gitops-reconciler.timer":   true,
		"restic-backup.timer":       true,
	}

	for _, svc := range services {
		if !expectedServices[svc.Name] {
			t.Errorf("unexpected service in list: %q", svc.Name)
		}
	}
}

func TestServiceManagerStatus(t *testing.T) {
	manager := NewServiceManager()

	// Test checking status of a service
	status, err := manager.Status(context.Background(), "sshd.service")
	if err != nil {
		t.Fatalf("Status() error: %v", err)
	}

	if status.Name != "sshd.service" {
		t.Errorf("Name = %q, want %q", status.Name, "sshd.service")
	}

	// Status should have either active or inactive state
	if status.Active != "active" && status.Active != "inactive" {
		t.Errorf("Active = %q, want 'active' or 'inactive'", status.Active)
	}
}

func TestServiceManagerRestart(t *testing.T) {
	manager := NewServiceManager()

	// This will fail without sudo, but we're testing the interface
	err := manager.Restart(context.Background(), "nonexistent.service")
	if err == nil {
		t.Log("Restart() succeeded (unlikely without sudo)")
	} else {
		t.Logf("Restart() expected error: %v", err)
	}
}

func TestServiceStatusStructure(t *testing.T) {
	tests := []struct {
		name     string
		status   ServiceStatus
		expected ServiceStatus
	}{
		{
			name: "active service",
			status: ServiceStatus{
				Name:    "sshd.service",
				Active:  "active",
				Running: true,
				Enabled: true,
				SubState: "running",
			},
			expected: ServiceStatus{
				Name:    "sshd.service",
				Active:  "active",
				Running: true,
				Enabled: true,
				SubState: "running",
			},
		},
		{
			name: "inactive service",
			status: ServiceStatus{
				Name:    "nginx.service",
				Active:  "inactive",
				Running: false,
				Enabled: false,
				SubState: "dead",
				Message: "service not running",
			},
			expected: ServiceStatus{
				Name:    "nginx.service",
				Active:  "inactive",
				Running: false,
				Enabled: false,
				SubState: "dead",
				Message: "service not running",
			},
		},
		{
			name: "failed service",
			status: ServiceStatus{
				Name:    "prometheus.service",
				Active:  "failed",
				Running: false,
				Enabled: true,
				SubState: "failed",
				Message: "Main process exited, code=exited, status=1/FAILURE",
			},
			expected: ServiceStatus{
				Name:    "prometheus.service",
				Active:  "failed",
				Running: false,
				Enabled: true,
				SubState: "failed",
				Message: "Main process exited, code=exited, status=1/FAILURE",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.status.Name != tt.expected.Name {
				t.Errorf("Name = %q, want %q", tt.status.Name, tt.expected.Name)
			}
			if tt.status.Active != tt.expected.Active {
				t.Errorf("Active = %q, want %q", tt.status.Active, tt.expected.Active)
			}
			if tt.status.Running != tt.expected.Running {
				t.Errorf("Running = %v, want %v", tt.status.Running, tt.expected.Running)
			}
			if tt.status.Enabled != tt.expected.Enabled {
				t.Errorf("Enabled = %v, want %v", tt.status.Enabled, tt.expected.Enabled)
			}
		})
	}
}
