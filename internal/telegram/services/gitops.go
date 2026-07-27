package services

import (
	"strings"
)

// GitOpsService provides GitOps reconciliation and deployment operations.
type GitOpsService struct {
	runner  *Runner
	repoDir string
	nix     *NixService
	git     *GitService
}

// NewGitOpsService creates a new GitOpsService.
func NewGitOpsService(runner *Runner, repoDir string, nix *NixService, git *GitService) *GitOpsService {
	return &GitOpsService{runner: runner, repoDir: repoDir, nix: nix, git: git}
}

// Reconcile runs the full GitOps reconciliation cycle.
func (s *GitOpsService) Reconcile() string {
	return s.runner.Run("ivali reconcile 2>&1 || echo 'ivali not available'", 120)
}

// Verify runs system verification.
func (s *GitOpsService) Verify() string {
	return s.runner.Run("ivali verify 2>&1 || echo 'ivali not available'", 60)
}

// TriggerBackup starts the restic backup service.
func (s *GitOpsService) TriggerBackup() (string, bool) {
	output := s.runner.Run(
		"systemctl start restic-backup 2>&1 && echo 'Backup started' || echo 'Failed to start backup'", 10)
	status := strings.Contains(output, "started")
	return output, status
}

// BackupStatus returns the restic backup service status.
func (s *GitOpsService) BackupStatus() string {
	return s.runner.Run("systemctl status restic-backup --no-pager 2>/dev/null | head -10", 5)
}

// ListSnapshots lists restic backup snapshots.
func (s *GitOpsService) ListSnapshots() string {
	output := s.runner.Run("restic snapshots 2>&1 | head -30 || echo 'restic not available'", 30)
	return output
}

// ReconcilerStatus returns the gitops-reconciler service status.
func (s *GitOpsService) ReconcilerStatus() string {
	return s.runner.Run("systemctl is-active gitops-reconciler 2>/dev/null || echo unknown", 5)
}

// ResticStatus returns the restic-backup service status.
func (s *GitOpsService) ResticStatus() string {
	return s.runner.Run("systemctl is-active restic-backup 2>/dev/null || echo inactive", 5)
}

// ResticLastRun returns the last restic backup execution timestamp.
func (s *GitOpsService) ResticLastRun() string {
	return s.runner.Run(
		"systemctl show restic-backup --property=ExecMainStartTimestamp 2>/dev/null | cut -d= -f2", 5)
}

// LastSnapshot returns the latest restic snapshot info.
func (s *GitOpsService) LastSnapshot() string {
	return s.runner.Run("restic snapshots --latest 1 --no-lock 2>/dev/null | tail -2 | head -1 || echo 'no snapshots'", 15)
}


