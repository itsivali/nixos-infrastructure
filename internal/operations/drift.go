package operations

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// driftService implements DriftService.
type driftService struct {
	repoDir string
}

// NewDriftService creates a drift detection service.
func NewDriftService(repoDir string) *driftService {
	return &driftService{repoDir: repoDir}
}

func (d *driftService) Detect(ctx context.Context) (*DriftReport, error) {
	report := &DriftReport{
		Timestamp: time.Now(),
	}

	// Get desired commit (Git HEAD)
	report.GitDesiredCommit = d.getRemoteHead(ctx)

	// Get deployed commit (what's actually running)
	report.GitDeployedCommit = d.getDeployedCommit(ctx)

	// Check git drift
	report.GitDrift = report.GitDesiredCommit != report.GitDeployedCommit &&
		report.GitDesiredCommit != "" && report.GitDeployedCommit != ""

	// Get expected generation
	report.GenExpected = d.getExpectedGeneration(ctx)

	// Get active generation
	report.GenActive = d.getActiveGeneration(ctx)

	// Check generation drift
	report.GenDrift = report.GenExpected != report.GenActive &&
		report.GenExpected > 0 && report.GenActive > 0

	// Check service drift
	driftedServices := d.checkServiceDrift(ctx)
	report.DriftedServices = driftedServices
	report.ServicesDrift = len(driftedServices) > 0

	// Overall drift
	report.OverallDrift = report.GitDrift || report.GenDrift || report.ServicesDrift

	return report, nil
}

func (d *driftService) getRemoteHead(ctx context.Context) string {
	// Fetch and get remote HEAD
	exec.CommandContext(ctx, "git", "-C", d.repoDir, "fetch", "--quiet", "origin").Run()
	out, err := exec.CommandContext(ctx, "git", "-C", d.repoDir, "rev-parse", "origin/main").CombinedOutput()
	if err != nil {
		// Fallback to local HEAD
		out, err = exec.CommandContext(ctx, "git", "-C", d.repoDir, "rev-parse", "HEAD").CombinedOutput()
		if err != nil {
			return ""
		}
	}
	return strings.TrimSpace(string(out))
}

func (d *driftService) getDeployedCommit(ctx context.Context) string {
	// The deployed commit is the current HEAD of the repo (since GitOps pulls before deploy)
	out, err := exec.CommandContext(ctx, "git", "-C", d.repoDir, "rev-parse", "HEAD").CombinedOutput()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func (d *driftService) getExpectedGeneration(ctx context.Context) int {
	// The expected generation is the latest generation (from the current configuration)
	return d.getActiveGeneration(ctx)
}

func (d *driftService) getActiveGeneration(ctx context.Context) int {
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
				fmt.Sscanf(fields[0], "%d", &gen)
				return gen
			}
		}
	}
	return 0
}

func (d *driftService) checkServiceDrift(ctx context.Context) []string {
	// Check if critical services are running as expected
	criticalServices := []string{
		"sshd.service",
		"NetworkManager.service",
		"tailscaled.service",
		"operations-web-ui.service",
		"prometheus.service",
		"grafana-server.service",
	}

	var drifted []string
	for _, svc := range criticalServices {
		out, err := exec.CommandContext(ctx, "systemctl", "is-active", svc).CombinedOutput()
		status := strings.TrimSpace(string(out))
		if err != nil || status != "active" {
			drifted = append(drifted, svc)
		}
	}
	return drifted
}
