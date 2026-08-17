package remediation

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/state"
)

type ServiceRestartAction struct{}

func NewServiceRestartAction() *ServiceRestartAction {
	return &ServiceRestartAction{}
}

func (a *ServiceRestartAction) Name() string { return "service-restart" }

func (a *ServiceRestartAction) CanFix(comp *state.ComponentStatus) bool {
	if comp == nil {
		return false
	}
	return comp.Kind == "service" || comp.Kind == "plugin"
}

func (a *ServiceRestartAction) Fix(comp *state.ComponentStatus) (*Result, error) {
	start := time.Now()

	serviceName := comp.Name
	if meta, ok := comp.Metadata["service"]; ok {
		serviceName = meta
	}

	cmd := exec.Command("systemctl", "restart", serviceName)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return &Result{
			Success:   false,
			Message:   fmt.Sprintf("failed to restart %s: %s", serviceName, strings.TrimSpace(string(output))),
			Duration:  time.Since(start),
			Timestamp: time.Now(),
		}, nil
	}

	time.Sleep(2 * time.Second)

	checkCmd := exec.Command("systemctl", "is-active", serviceName)
	checkOutput, _ := checkCmd.CombinedOutput()
	status := strings.TrimSpace(string(checkOutput))

	if status == "active" {
		return &Result{
			Success:   true,
			Message:   fmt.Sprintf("service %s restarted successfully", serviceName),
			Duration:  time.Since(start),
			Timestamp: time.Now(),
		}, nil
	}

	return &Result{
		Success:   false,
		Message:   fmt.Sprintf("service %s restarted but status is %s", serviceName, status),
		Duration:  time.Since(start),
		Timestamp: time.Now(),
	}, nil
}

type NixOSRebuildAction struct{}

func NewNixOSRebuildAction() *NixOSRebuildAction {
	return &NixOSRebuildAction{}
}

func (a *NixOSRebuildAction) Name() string { return "nixos-rebuild" }

func (a *NixOSRebuildAction) CanFix(comp *state.ComponentStatus) bool {
	if comp == nil {
		return false
	}
	return comp.Kind == "nixos" && (comp.State == state.StateDegraded || comp.State == state.StateOffline)
}

func (a *NixOSRebuildAction) Fix(comp *state.ComponentStatus) (*Result, error) {
	start := time.Now()

	host, _ := os.Hostname()
	cmd := exec.Command("sudo", "nixos-rebuild", "switch", "--flake", "/home/ivali/nixos-infrastructure#"+host)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return &Result{
			Success:   false,
			Message:   fmt.Sprintf("rebuild failed: %s", strings.TrimSpace(string(output))),
			Duration:  time.Since(start),
			Timestamp: time.Now(),
		}, nil
	}

	return &Result{
		Success:   true,
		Message:   "NixOS rebuild completed successfully",
		Duration:  time.Since(start),
		Timestamp: time.Now(),
	}, nil
}

type DiskCleanupAction struct{}

func NewDiskCleanupAction() *DiskCleanupAction {
	return &DiskCleanupAction{}
}

func (a *DiskCleanupAction) Name() string { return "disk-cleanup" }

func (a *DiskCleanupAction) CanFix(comp *state.ComponentStatus) bool {
	if comp == nil {
		return true
	}
	return comp.Name == "disk" || comp.Name == "storage"
}

func (a *DiskCleanupAction) Fix(comp *state.ComponentStatus) (*Result, error) {
	start := time.Now()

	gcCmd := exec.Command("sudo", "nix-collect-garbage", "-d")
	gcOutput, err := gcCmd.CombinedOutput()
	if err != nil {
		return &Result{
			Success:   false,
			Message:   fmt.Sprintf("garbage collection failed: %s", strings.TrimSpace(string(gcOutput))),
			Duration:  time.Since(start),
			Timestamp: time.Now(),
		}, nil
	}

	trimCmd := exec.Command("sudo", "nix-store", "--optimise")
	trimOutput, err := trimCmd.CombinedOutput()
	if err != nil {
		return &Result{
			Success:   false,
			Message:   fmt.Sprintf("store optimization failed: %s", strings.TrimSpace(string(trimOutput))),
			Duration:  time.Since(start),
			Timestamp: time.Now(),
		}, nil
	}

	return &Result{
		Success:   true,
		Message:   "disk cleanup completed (garbage collection + store optimization)",
		Duration:  time.Since(start),
		Timestamp: time.Now(),
	}, nil
}

type NetworkResetAction struct{}

func NewNetworkResetAction() *NetworkResetAction {
	return &NetworkResetAction{}
}

func (a *NetworkResetAction) Name() string { return "network-reset" }

func (a *NetworkResetAction) CanFix(comp *state.ComponentStatus) bool {
	if comp == nil {
		return false
	}
	return comp.Name == "network" || comp.Name == "tailscale" || comp.Kind == "network"
}

func (a *NetworkResetAction) Fix(comp *state.ComponentStatus) (*Result, error) {
	start := time.Now()

	serviceName := "tailscaled"
	if comp != nil && comp.Metadata["service"] != "" {
		serviceName = comp.Metadata["service"]
	}

	cmd := exec.Command("sudo", "systemctl", "restart", serviceName)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return &Result{
			Success:   false,
			Message:   fmt.Sprintf("failed to restart %s: %s", serviceName, strings.TrimSpace(string(output))),
			Duration:  time.Since(start),
			Timestamp: time.Now(),
		}, nil
	}

	time.Sleep(3 * time.Second)

	statusCmd := exec.Command("systemctl", "is-active", serviceName)
	statusOutput, _ := statusCmd.CombinedOutput()
	status := strings.TrimSpace(string(statusOutput))

	if status == "active" {
		return &Result{
			Success:   true,
			Message:   fmt.Sprintf("network service %s restarted successfully", serviceName),
			Duration:  time.Since(start),
			Timestamp: time.Now(),
		}, nil
	}

	return &Result{
		Success:   false,
		Message:   fmt.Sprintf("network service %s restarted but status is %s", serviceName, status),
		Duration:  time.Since(start),
		Timestamp: time.Now(),
	}, nil
}
