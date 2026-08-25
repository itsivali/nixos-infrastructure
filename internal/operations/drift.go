package operations

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// driftService implements DriftService.
type driftService struct {
	repoDir  string
	stateDir string
}

// NewDriftService creates a drift detection service.
func NewDriftService(repoDir string) *driftService {
	return &driftService{
		repoDir:  repoDir,
		stateDir: "/var/lib/deployment",
	}
}

func (d *driftService) Detect(ctx context.Context) (*DriftReport, error) {
	report := &DriftReport{
		Timestamp: time.Now(),
	}

	// Get desired commit (Git remote HEAD)
	report.GitDesiredCommit = d.getRemoteHead(ctx)

	// Get deployed commit from deployment provenance (not just git HEAD)
	report.GitDeployedCommit = d.getDeployedCommitFromProvenance(ctx)

	// Check git drift
	report.GitDrift = report.GitDesiredCommit != report.GitDeployedCommit &&
		report.GitDesiredCommit != "" && report.GitDeployedCommit != ""

	// Get expected generation from deployment provenance
	report.GenExpected = d.getExpectedGenerationFromProvenance(ctx)

	// Get active generation (current running generation)
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
	_ = exec.CommandContext(ctx, "git", "-C", d.repoDir, "fetch", "--quiet", "origin").Run()
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

// getDeployedCommitFromProvenance reads the deployed commit from deployment provenance record
func (d *driftService) getDeployedCommitFromProvenance(ctx context.Context) string {
	statePath := filepath.Join(d.stateDir, "last-deploy.json")
	data, err := os.ReadFile(statePath)
	if err != nil {
		// No provenance record, fallback to git HEAD
		return d.getDeployedCommitFallback(ctx)
	}

	var record DeploymentRecord
	if err := json.Unmarshal(data, &record); err != nil {
		return d.getDeployedCommitFallback(ctx)
	}

	// Use ResolvedSHA if available, otherwise CommitSHA
	if record.ResolvedSHA != "" {
		return record.ResolvedSHA
	}
	if record.CommitSHA != "" {
		return record.CommitSHA
	}

	return d.getDeployedCommitFallback(ctx)
}

func (d *driftService) getDeployedCommitFallback(ctx context.Context) string {
	// Fallback: get current HEAD of the repo
	out, err := exec.CommandContext(ctx, "git", "-C", d.repoDir, "rev-parse", "HEAD").CombinedOutput()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// getExpectedGenerationFromProvenance reads the expected generation from deployment provenance
func (d *driftService) getExpectedGenerationFromProvenance(ctx context.Context) int {
	statePath := filepath.Join(d.stateDir, "last-deploy.json")
	data, err := os.ReadFile(statePath)
	if err != nil {
		// No provenance record, fallback to active generation
		return d.getActiveGeneration(ctx)
	}

	var record DeploymentRecord
	if err := json.Unmarshal(data, &record); err != nil {
		return d.getActiveGeneration(ctx)
	}

	if record.Generation > 0 {
		return record.Generation
	}

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
				_, _ = fmt.Sscanf(fields[0], "%d", &gen)
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
