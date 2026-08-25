package operations

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// healthService implements HealthService.
type healthService struct {
	repoDir string
}

// NewHealthService creates a health service.
func NewHealthService(repoDir string) *healthService {
	return &healthService{repoDir: repoDir}
}

func (h *healthService) Check(ctx context.Context) (*OverallHealth, error) {
	health := &OverallHealth{
		Timestamp:  time.Now(),
		Healthy:    true,
		Status:     "healthy",
		Components: make(map[string]ComponentHealth),
	}

	// Check systemd
	health.Components["systemd"] = h.checkSystemd(ctx)

	// Check network
	health.Components["network"] = h.checkNetwork(ctx)

	// Check Tailscale
	health.Components["tailscale"] = h.checkTailscale(ctx)

	// Check DNS
	health.Components["dns"] = h.checkDNS(ctx)

	// Check disk
	health.Components["disk"] = h.checkDisk(ctx, "/")

	// Check critical services
	services := []string{
		"sshd.service",
		"NetworkManager.service",
		"tailscaled.service",
		"nginx.service",
		"operations-web-ui.service",
		"prometheus.service",
		"grafana-server.service",
	}
	for _, svc := range services {
		name := strings.TrimSuffix(svc, ".service")
		health.Components[name] = h.checkSystemdService(ctx, svc)
	}

	// Check NixOS generation
	health.NixOSGen = h.getCurrentGeneration(ctx)

	// Check git commit
	health.GitCommit = h.getCurrentCommit(ctx)

	// Determine overall status
	for _, comp := range health.Components {
		if !comp.Healthy {
			health.Healthy = false
			health.Status = "degraded"
			break
		}
	}

	return health, nil
}

func (h *healthService) CheckComponent(ctx context.Context, name string) (*ComponentHealth, error) {
	switch name {
	case "systemd":
		comp := h.checkSystemd(ctx)
		return &comp, nil
	case "network":
		comp := h.checkNetwork(ctx)
		return &comp, nil
	case "tailscale":
		comp := h.checkTailscale(ctx)
		return &comp, nil
	case "dns":
		comp := h.checkDNS(ctx)
		return &comp, nil
	case "disk":
		comp := h.checkDisk(ctx, "/")
		return &comp, nil
	default:
		// Try as systemd service
		comp := h.checkSystemdService(ctx, name)
		return &comp, nil
	}
}

func (h *healthService) checkSystemd(ctx context.Context) ComponentHealth {
	comp := ComponentHealth{Name: "systemd", Healthy: true, Status: "running"}
	out, err := exec.CommandContext(ctx, "systemctl", "is-system-running").CombinedOutput()
	status := strings.TrimSpace(string(out))
	if err != nil || status != "running" {
		comp.Healthy = false
		comp.Status = status
		comp.Message = fmt.Sprintf("systemd state: %s", status)
	}
	return comp
}

func (h *healthService) checkNetwork(ctx context.Context) ComponentHealth {
	comp := ComponentHealth{Name: "network", Healthy: true, Status: "ok"}
	cmd := exec.CommandContext(ctx, "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
		"--max-time", "5", "https://1.1.1.1")
	out, err := cmd.Output()
	if err != nil || strings.TrimSpace(string(out)) != "200" {
		comp.Healthy = false
		comp.Status = "no internet"
		comp.Message = "internet connectivity check failed"
	}
	return comp
}

func (h *healthService) checkTailscale(ctx context.Context) ComponentHealth {
	comp := ComponentHealth{Name: "tailscale", Healthy: true, Status: "connected"}
	out, err := exec.CommandContext(ctx, "tailscale", "status").CombinedOutput()
	if err != nil {
		comp.Healthy = false
		comp.Status = "not running"
		comp.Message = "tailscale not available"
		return comp
	}
	if !strings.Contains(string(out), "vpn") && !strings.Contains(string(out), "Connected") {
		comp.Healthy = false
		comp.Status = "disconnected"
	}
	return comp
}

func (h *healthService) checkDNS(ctx context.Context) ComponentHealth {
	comp := ComponentHealth{Name: "dns", Healthy: true, Status: "ok"}
	if out, err := exec.CommandContext(ctx, "host", "gitlab.com").CombinedOutput(); err != nil {
		comp.Healthy = false
		comp.Status = "failed"
		comp.Message = string(out)
	}
	return comp
}

func (h *healthService) checkDisk(ctx context.Context, mount string) ComponentHealth {
	comp := ComponentHealth{Name: "disk", Healthy: true, Status: "ok"}
	out, err := exec.CommandContext(ctx, "df", "-h", mount).CombinedOutput()
	if err != nil {
		comp.Healthy = false
		comp.Status = "error"
		return comp
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) >= 2 {
		fields := strings.Fields(lines[1])
		if len(fields) >= 5 {
			pctStr := strings.TrimSuffix(fields[4], "%")
			if pct, err := strconv.Atoi(pctStr); err == nil {
				if pct >= 90 {
					comp.Healthy = false
					comp.Status = fmt.Sprintf("%d%% used (critical)", pct)
				} else if pct >= 80 {
					comp.Status = fmt.Sprintf("%d%% used (warning)", pct)
				} else {
					comp.Status = fmt.Sprintf("%d%% used", pct)
				}
			}
		}
	}
	return comp
}

func (h *healthService) checkSystemdService(ctx context.Context, name string) ComponentHealth {
	comp := ComponentHealth{Name: name, Healthy: false, Status: "inactive"}
	out, err := exec.CommandContext(ctx, "systemctl", "is-active", name).CombinedOutput()
	status := strings.TrimSpace(string(out))
	if err == nil && status == "active" {
		comp.Healthy = true
		comp.Status = "active"
	} else {
		comp.Status = status
		comp.Message = fmt.Sprintf("service status: %s", status)
	}
	return comp
}

func (h *healthService) getCurrentGeneration(ctx context.Context) int {
	out, err := exec.CommandContext(ctx, "nix-env", "--list-generations",
		"--profile", "/nix/var/nix/profiles/system").CombinedOutput()
	if err != nil {
		return 0
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	for _, line := range lines {
		if strings.Contains(line, "*") {
			fields := strings.Fields(line)
			if len(fields) > 0 {
				var gen int
				_, _ = fmt.Sscanf(fields[0], "%d", &gen)
				return gen
			}
		}
	}
	return 0
}

func (h *healthService) getCurrentCommit(ctx context.Context) string {
	out, err := exec.CommandContext(ctx, "git", "-C", h.repoDir, "rev-parse", "--short", "HEAD").CombinedOutput()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}
