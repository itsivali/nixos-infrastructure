package operations

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// fileLock provides a simple file-based lock for deployment serialization.
type fileLock struct {
	path string
	fd   *os.File
	mu   sync.Mutex
}

// deploymentService implements DeploymentService.
type deploymentService struct {
	repoDir    string
	stateDir   string
	lock       *fileLock
	audit      AuditLogger
}

// NewDeploymentService creates a deployment service rooted at the given directory.
func NewDeploymentService(repoDir string, audit AuditLogger) *deploymentService {
	stateDir := "/var/lib/deployment"
	return &deploymentService{
		repoDir:  repoDir,
		stateDir: stateDir,
		lock: &fileLock{
			path: "/run/deploy.lock",
		},
		audit: audit,
	}
}

func (d *deploymentService) Deploy(ctx context.Context, opts DeployOpts) (*DeploymentRecord, error) {
	startTime := time.Now()

	// Generate deployment ID
	host, _ := os.Hostname()
	deployID := fmt.Sprintf("%s-%s", startTime.Format("20060102-150405"), host)

	record := &DeploymentRecord{
		ID:        deployID,
		Actor:     opts.Actor,
		Source:    opts.Source,
		Timestamp: startTime,
		State:     StatePending,
	}

	// Capture current generation
	record.PreviousGen = d.getCurrentGeneration(ctx)

	// Capture current commit
	record.PreviousSHA = d.getCurrentCommit(ctx)

	if opts.Commit != "" {
		record.CommitSHA = opts.Commit
	} else {
		record.CommitSHA = record.PreviousSHA
	}

	// State: validating
	record.State = StateValidating
	d.saveState(record)

	// Validate flake
	if err := d.validateFlake(ctx); err != nil {
		record.State = StateFailed
		record.Error = fmt.Sprintf("flake validation failed: %v", err)
		d.saveState(record)
		d.auditDeployment(ctx, record, "failed")
		return record, err
	}

	// State: building
	record.State = StateBuilding
	d.saveState(record)

	// Build system
	host = d.getHost()
	if err := d.buildSystem(ctx, host); err != nil {
		record.State = StateFailed
		record.Error = fmt.Sprintf("build failed: %v", err)
		d.saveState(record)
		d.auditDeployment(ctx, record, "failed")
		return record, err
	}

	// State: activating
	record.State = StateActivating
	d.saveState(record)

	// Activate
	if err := d.activateSystem(ctx, host); err != nil {
		record.State = StateFailed
		record.Error = fmt.Sprintf("activation failed: %v", err)
		d.saveState(record)
		d.auditDeployment(ctx, record, "failed")
		return record, err
	}

	// Wait for services to settle
	time.Sleep(10 * time.Second)

	// State: verifying
	record.State = StateVerifying
	d.saveState(record)

	// Get new generation
	record.Generation = d.getCurrentGeneration(ctx)

	// Calculate duration
	record.Duration = time.Since(startTime).Round(time.Second).String()

	// Health check
	if err := d.healthCheck(ctx); err != nil {
		record.State = StateFailed
		record.Error = fmt.Sprintf("health check failed: %v", err)
		record.HealthResult = "failed"
		d.saveState(record)
		d.auditDeployment(ctx, record, "failed")
		return record, fmt.Errorf("deployment health check failed: %w", err)
	}

	record.HealthResult = "passed"

	// Capture changelog
	record.Changelog = d.getChangelog(ctx, record.PreviousSHA, record.CommitSHA)
	record.ChangedFiles = d.getChangedFiles(ctx, record.PreviousSHA, record.CommitSHA)

	// State: complete
	record.State = StateComplete
	record.Status = "deployed"
	d.saveState(record)
	d.auditDeployment(ctx, record, "success")

	return record, nil
}

func (d *deploymentService) Rollback(ctx context.Context, opts RollbackOpts) (*RollbackResult, error) {
	startTime := time.Now()
	result := &RollbackResult{}

	// Capture current generation
	result.FromGen = d.getCurrentGeneration(ctx)

	// Determine target generation
	if opts.Generation > 0 {
		// Validate the target generation exists
		if !d.generationExists(ctx, opts.Generation) {
			return nil, fmt.Errorf("generation %d does not exist", opts.Generation)
		}
	}

	// Execute rollback
	// If Generation > 0, activate that specific generation
	// If Generation == 0, rollback to previous generation
	var cmd *exec.Cmd
	if opts.Generation > 0 {
		cmd = exec.CommandContext(ctx, "nix-env", "--profile",
			"/nix/var/nix/profiles/system", "--rollback", fmt.Sprintf("--generation=%d", opts.Generation))
	} else {
		cmd = exec.CommandContext(ctx, "nixos-rebuild", "switch", "--rollback")
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		result.Error = fmt.Sprintf("rollback command failed: %s", string(out))
		if d.audit != nil {
			d.audit.Log(ctx, AuditEntry{
				Timestamp: startTime,
				Actor:     opts.Actor,
				Action:    "rollback",
				Target:    fmt.Sprintf("generation:%d", opts.Generation),
				Result:    "failed",
				Error:     result.Error,
			})
		}
		return result, fmt.Errorf("rollback failed: %w\n%s", err, string(out))
	}

	// Wait for services to settle
	time.Sleep(10 * time.Second)

	// Get new generation
	result.ToGen = d.getCurrentGeneration(ctx)

	// Health check after rollback
	healthErr := d.healthCheck(ctx)
	result.HealthPassed = healthErr == nil

	// Rollback is only successful if health check passes
	result.Success = result.HealthPassed

	// Audit
	if d.audit != nil {
		resultStr := "success"
		if !result.Success {
			resultStr = "failed"
		}
		d.audit.Log(ctx, AuditEntry{
			Timestamp:  startTime,
			Actor:      opts.Actor,
			Action:     "rollback",
			Target:     fmt.Sprintf("generation:%d", result.ToGen),
			Result:     resultStr,
			Generation: result.ToGen,
			Error:      result.Error,
		})
	}

	return result, nil
}

func (d *deploymentService) Status(ctx context.Context) (*DeploymentRecord, error) {
	// Try to read last deployment state
	statePath := filepath.Join(d.stateDir, "last-deploy.json")
	data, err := os.ReadFile(statePath)
	if err != nil {
		// No deployment record — construct from current state
		return &DeploymentRecord{
			Generation: d.getCurrentGeneration(ctx),
			CommitSHA:  d.getCurrentCommit(ctx),
			State:      StateComplete,
			Status:     "no deployment record",
			Timestamp:  time.Now(),
		}, nil
	}

	var record DeploymentRecord
	if err := json.Unmarshal(data, &record); err != nil {
		return nil, fmt.Errorf("parse deployment state: %w", err)
	}
	return &record, nil
}

func (d *deploymentService) History(ctx context.Context, limit int) ([]DeploymentRecord, error) {
	historyDir := filepath.Join(d.stateDir, "history")
	entries, err := os.ReadDir(historyDir)
	if err != nil {
		return nil, nil
	}

	var records []DeploymentRecord
	for i := len(entries) - 1; i >= 0 && len(records) < limit; i-- {
		if entries[i].IsDir() {
			continue
		}
		data, err := os.ReadFile(filepath.Join(historyDir, entries[i].Name()))
		if err != nil {
			continue
		}
		var record DeploymentRecord
		if err := json.Unmarshal(data, &record); err != nil {
			continue
		}
		records = append(records, record)
	}
	return records, nil
}

func (d *deploymentService) AcquireLock(ctx context.Context) (func(), error) {
	d.lock.mu.Lock()
	defer d.lock.mu.Unlock()

	fd, err := os.OpenFile(d.lock.path, os.O_CREATE|os.O_RDWR, 0660)
	if err != nil {
		return nil, fmt.Errorf("open lock file: %w", err)
	}

	if err := syscallFlock(fd); err != nil {
		fd.Close()
		return nil, fmt.Errorf("acquire lock: %w", err)
	}

	d.lock.fd = fd

	release := func() {
		syscallFlockUnlock(fd)
		fd.Close()
	}
	return release, nil
}

func (d *deploymentService) saveState(record *DeploymentRecord) {
	os.MkdirAll(d.stateDir, 0755)

	data, err := json.MarshalIndent(record, "", "  ")
	if err != nil {
		return
	}

	statePath := filepath.Join(d.stateDir, "last-deploy.json")
	os.WriteFile(statePath, data, 0644)

	// Also save to history
	historyDir := filepath.Join(d.stateDir, "history")
	os.MkdirAll(historyDir, 0755)
	historyPath := filepath.Join(historyDir, fmt.Sprintf("%s.json", record.ID))
	os.WriteFile(historyPath, data, 0644)

	// Keep only last 50 history entries
	cleanHistory(historyDir, 50)
}

func (d *deploymentService) auditDeployment(ctx context.Context, record *DeploymentRecord, result string) {
	if d.audit == nil {
		return
	}
	d.audit.Log(ctx, AuditEntry{
		Timestamp:  record.Timestamp,
		Actor:      record.Actor,
		Action:     "deploy",
		Target:     record.CommitSHA,
		Source:     record.Source,
		Result:     result,
		CommitSHA:  record.CommitSHA,
		Generation: record.Generation,
		Error:      record.Error,
	})
}

func (d *deploymentService) getCurrentGeneration(ctx context.Context) int {
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

func (d *deploymentService) getCurrentCommit(ctx context.Context) string {
	out, err := exec.CommandContext(ctx, "git", "-C", d.repoDir, "rev-parse", "HEAD").CombinedOutput()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func (d *deploymentService) getHost() string {
	if out, err := exec.Command("hostname").Output(); err == nil {
		return strings.TrimSpace(string(out))
	}
	return "unknown"
}

func (d *deploymentService) validateFlake(ctx context.Context) error {
	cmd := exec.CommandContext(ctx, "nix", "flake", "check", "--no-build",
		"--extra-experimental-features", "nix-command flakes",
		filepath.Join(d.repoDir, "flake.nix"))
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s", string(out))
	}
	return nil
}

func (d *deploymentService) buildSystem(ctx context.Context, host string) error {
	cmd := exec.CommandContext(ctx, "nix", "build",
		fmt.Sprintf(".#nixosConfigurations.%s.config.system.build.toplevel", host),
		"--extra-experimental-features", "nix-command flakes")
	cmd.Dir = d.repoDir
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s", string(out))
	}
	return nil
}

func (d *deploymentService) activateSystem(ctx context.Context, host string) error {
	cmd := exec.CommandContext(ctx, "sudo", "nixos-rebuild", "switch",
		"--flake", fmt.Sprintf("%s#%s", d.repoDir, host),
		"--extra-experimental-features", "nix-command flakes")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s", string(out))
	}
	return nil
}

func (d *deploymentService) healthCheck(ctx context.Context) error {
	scriptPath := filepath.Join(d.repoDir, "scripts", "deployment-health.sh")
	cmd := exec.CommandContext(ctx, scriptPath)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("health check failed: %s", string(out))
	}
	return nil
}

func (d *deploymentService) generationExists(ctx context.Context, gen int) bool {
	out, err := exec.CommandContext(ctx, "nix-env", "--list-generations",
		"--profile", "/nix/var/nix/profiles/system").CombinedOutput()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), fmt.Sprintf("%d ", gen))
}

func (d *deploymentService) getChangelog(ctx context.Context, from, to string) string {
	if from == "" || to == "" || from == to {
		return ""
	}
	cmd := exec.CommandContext(ctx, "git", "-C", d.repoDir, "log", "--oneline", fmt.Sprintf("%s..%s", from, to))
	out, err := cmd.CombinedOutput()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func (d *deploymentService) getChangedFiles(ctx context.Context, from, to string) string {
	if from == "" || to == "" || from == to {
		return ""
	}
	cmd := exec.CommandContext(ctx, "git", "-C", d.repoDir, "diff", "--name-only", fmt.Sprintf("%s..%s", from, to))
	out, err := cmd.CombinedOutput()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func cleanHistory(dir string, maxEntries int) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	if len(entries) <= maxEntries {
		return
	}
	for i := 0; i < len(entries)-maxEntries; i++ {
		os.Remove(filepath.Join(dir, entries[i].Name()))
	}
}
