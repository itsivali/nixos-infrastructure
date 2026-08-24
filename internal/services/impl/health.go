package impl

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/services"
)

// SystemHealthChecker implements services.HealthChecker by probing systemd,
// network, and disk directly. It replaces the three independent health check
// implementations: deployment-health.sh, health-endpoint.nix, and
// internal/platform/health.
type SystemHealthChecker struct{}

// NewSystemHealthChecker creates a health checker that probes the local system.
func NewSystemHealthChecker() *SystemHealthChecker {
	return &SystemHealthChecker{}
}

func (h *SystemHealthChecker) CheckSystem(ctx context.Context) (*services.SystemHealth, error) {
	sh := &services.SystemHealth{Healthy: true}

	// Default systemd services to check
	defaultServices := []string{
		"prometheus", "grafana-server", "loki",
		"restic-backup.timer", "deployment-health.timer",
	}
	svcHealth, err := h.CheckServices(ctx, defaultServices)
	if err == nil {
		sh.Services = svcHealth
		for _, s := range svcHealth {
			if !s.Healthy {
				sh.Healthy = false
			}
		}
	}

	netHealth, err := h.CheckNetwork(ctx)
	if err == nil {
		sh.Network = netHealth
		if !netHealth.Internet || !netHealth.DNS {
			sh.Healthy = false
		}
	}

	diskHealth, err := h.CheckDisk(ctx, []string{"/", "/home"})
	if err == nil {
		sh.Disk = diskHealth
		for _, d := range diskHealth {
			if d.UsedPercent > 90 {
				sh.Healthy = false
			}
		}
	}

	// NixOS generation
	if out, err := exec.CommandContext(ctx, "nixos-rebuild", "list-generations", "--no-out-link").CombinedOutput(); err == nil {
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		for _, line := range lines {
			if strings.Contains(line, "*") {
				fields := strings.Fields(line)
				if len(fields) > 0 {
					sh.NixOSGen, _ = strconv.Atoi(fields[0])
				}
				break
			}
		}
	}

	if sh.Healthy {
		sh.Message = "all systems nominal"
	} else {
		sh.Message = "issues detected — check individual components"
	}
	return sh, nil
}

func (h *SystemHealthChecker) CheckServices(ctx context.Context, serviceNames []string) (map[string]services.ServiceHealth, error) {
	result := make(map[string]services.ServiceHealth, len(serviceNames))
	for _, name := range serviceNames {
		health := services.ServiceHealth{Name: name}
		out, err := exec.CommandContext(ctx, "systemctl", "is-active", name).CombinedOutput()
		status := strings.TrimSpace(string(out))
		health.Healthy = (err == nil && status == "active")
		if health.Healthy {
			health.Message = "active"
		} else {
			health.Message = status
		}
		result[name] = health
	}
	return result, nil
}

func (h *SystemHealthChecker) CheckNetwork(ctx context.Context) (*services.NetworkHealth, error) {
	nh := &services.NetworkHealth{}

	// Tailscale
	if out, err := exec.CommandContext(ctx, "tailscale", "status").CombinedOutput(); err == nil {
		nh.Tailscale = strings.Contains(string(out), "vpn")
	} else {
		nh.Tailscale = false
	}

	// Internet (curl to Cloudflare DNS)
	cmd := exec.CommandContext(ctx, "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
		"--max-time", "5", "https://1.1.1.1")
	if out, err := cmd.Output(); err == nil && strings.TrimSpace(string(out)) == "200" {
		nh.Internet = true
	}

	// DNS
	if out, err := exec.CommandContext(ctx, "host", "google.com").CombinedOutput(); err == nil {
		nh.DNS = !strings.Contains(string(out), "not found")
	}

	nh.Message = "ok"
	if !nh.Internet {
		nh.Message = "no internet connectivity"
	} else if !nh.DNS {
		nh.Message = "DNS resolution failing"
	}
	return nh, nil
}

func (h *SystemHealthChecker) CheckDisk(ctx context.Context, mounts []string) (map[string]services.DiskHealth, error) {
	result := make(map[string]services.DiskHealth, len(mounts))
	for _, mount := range mounts {
		dh := services.DiskHealth{Mount: mount}
		cmd := exec.CommandContext(ctx, "df", "-B1", mount)
		out, err := cmd.Output()
		if err != nil {
			dh.Message = fmt.Sprintf("df failed: %v", err)
			result[mount] = dh
			continue
		}
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		if len(lines) < 2 {
			dh.Message = "no output from df"
			result[mount] = dh
			continue
		}
		fields := strings.Fields(lines[1])
		if len(fields) >= 4 {
			dh.Total, _ = strconv.ParseUint(fields[1], 10, 64)
			used, _ := strconv.ParseUint(fields[2], 10, 64)
			dh.Available, _ = strconv.ParseUint(fields[3], 10, 64)
			if dh.Total > 0 {
				dh.UsedPercent = float64(used) / float64(dh.Total) * 100
			}
			dh.Message = fmt.Sprintf("%.1f%% used", dh.UsedPercent)
		}
		result[mount] = dh
	}
	return result, nil
}

// CheckDeploymentHealth runs deployment-health.sh --json and parses the results.
func (h *SystemHealthChecker) CheckDeploymentHealth(ctx context.Context) (*services.DeploymentHealth, error) {
	scriptPath := "/home/ivali/nixos-infrastructure/scripts/deployment-health.sh"
	out, err := exec.CommandContext(ctx, scriptPath, "--json").CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("deployment-health failed: %w\n%s", err, string(out))
	}

	var dh services.DeploymentHealth
	if err := json.Unmarshal(out, &dh); err != nil {
		return nil, fmt.Errorf("parse deployment-health output: %w\n%s", err, string(out))
	}

	dh.Healthy = dh.Failed == 0
	return &dh, nil
}
