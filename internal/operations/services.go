package operations

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
)

// serviceManager implements ServiceManager.
type serviceManager struct{}

// NewServiceManager creates a service manager.
func NewServiceManager() *serviceManager {
	return &serviceManager{}
}

func (s *serviceManager) List(ctx context.Context) ([]ServiceStatus, error) {
	criticalServices := []string{
		"sshd.service",
		"NetworkManager.service",
		"tailscaled.service",
		"nginx.service",
		"prometheus.service",
		"grafana-server.service",
		"loki.service",
		"alertmanager.service",
		"operations-web-ui.service",
		"deployment-health.timer",
		"gitops-reconciler.timer",
		"restic-backup.timer",
	}

	var statuses []ServiceStatus
	for _, svc := range criticalServices {
		status, err := s.Status(ctx, svc)
		if err != nil {
			continue
		}
		statuses = append(statuses, *status)
	}
	return statuses, nil
}

func (s *serviceManager) Status(ctx context.Context, name string) (*ServiceStatus, error) {
	status := &ServiceStatus{Name: name}

	// Check if active
	out, err := exec.CommandContext(ctx, "systemctl", "is-active", name).CombinedOutput()
	active := strings.TrimSpace(string(out))
	if err == nil && active == "active" {
		status.Active = active
		status.Running = true
	} else {
		status.Active = active
		status.Running = false
	}

	// Check if enabled
	out, err = exec.CommandContext(ctx, "systemctl", "is-enabled", name).CombinedOutput()
	enabled := strings.TrimSpace(string(out))
	status.Enabled = (err == nil && enabled == "enabled")

	// Get sub-state
	out, err = exec.CommandContext(ctx, "systemctl", "show", name, "--property=SubState").CombinedOutput()
	if err == nil {
		subState := strings.TrimSpace(string(out))
		subState = strings.TrimPrefix(subState, "SubState=")
		status.SubState = subState
	}

	// Get message if not active
	if !status.Running {
		out, err = exec.CommandContext(ctx, "systemctl", "status", name, "--no-pager").CombinedOutput()
		if err == nil {
			lines := strings.Split(string(out), "\n")
			if len(lines) > 1 {
				status.Message = strings.TrimSpace(lines[1])
			}
		}
	}

	return status, nil
}

func (s *serviceManager) Restart(ctx context.Context, name string) error {
	cmd := exec.CommandContext(ctx, "sudo", "systemctl", "restart", name)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("restart %s: %w: %s", name, err, string(out))
	}
	return nil
}
