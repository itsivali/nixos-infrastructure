package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// DiffCommand shows the flake check output for the repository.
type DiffCommand struct {
	api *telegram.API
}

func NewDiffCommand(config *telegram.Config) *DiffCommand {
	return &DiffCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *DiffCommand) Name() string                      { return "diff" }
func (c *DiffCommand) Description() string               { return "Show flake check results" }
func (c *DiffCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *DiffCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("cd /home/ivali/nixos-infrastructure && nix flake check --no-build 2>&1 | head -20", 60)
	output = strings.TrimSpace(output)
	if output == "" {
		output = "(no issues found)"
	}
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("*Flake Check*\n```%s\n```", output), 3500)
}

// GitopsReconcileCommand triggers a full GitOps reconciliation cycle.
type GitopsReconcileCommand struct {
	api *telegram.API
}

func NewGitopsReconcileCommand(config *telegram.Config) *GitopsReconcileCommand {
	return &GitopsReconcileCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *GitopsReconcileCommand) Name() string                      { return "reconcile" }
func (c *GitopsReconcileCommand) Description() string               { return "Trigger GitOps reconciliation" }
func (c *GitopsReconcileCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *GitopsReconcileCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:reconcile" {
		_ = c.api.SendMarkdown(msg.ChatID, "Starting reconciliation...")
		output := runCmd("ivali reconcile 2>&1 || echo 'ivali not available'", 120)
		return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("*Reconciliation*\n```%s\n```", output), 3500)
	}
	return sendConfirm(c.api, msg.ChatID, "reconcile",
		"*Confirm reconcile?*\n\nThis will pull latest changes, rebuild, and verify.")
}

// VerifyCommand runs system verification.
type VerifyCommand struct {
	api *telegram.API
}

func NewVerifyCommand(config *telegram.Config) *VerifyCommand {
	return &VerifyCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *VerifyCommand) Name() string                      { return "verify" }
func (c *VerifyCommand) Description() string               { return "Verify system configuration" }
func (c *VerifyCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *VerifyCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("ivali verify 2>&1 || echo 'ivali not available'", 60)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("*Verification*\n```%s\n```", output), 3500)
}

// GitopsBackupCommand triggers a restic backup.
type GitopsBackupCommand struct {
	api *telegram.API
}

func NewGitopsBackupCommand(config *telegram.Config) *GitopsBackupCommand {
	return &GitopsBackupCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *GitopsBackupCommand) Name() string                      { return "backup_now" }
func (c *GitopsBackupCommand) Description() string               { return "Trigger restic backup" }
func (c *GitopsBackupCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *GitopsBackupCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:backup_now" {
		_ = c.api.SendMarkdown(msg.ChatID, "Starting restic backup...")
		output := runCmd("systemctl start restic-backup 2>&1 && echo 'Backup started' || echo 'Failed to start backup'", 10)
		output = strings.TrimSpace(output)
		if strings.Contains(output, "started") {
			status := runCmd("systemctl status restic-backup --no-pager 2>/dev/null | head -10", 5)
			return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("*Backup Started*\n```%s\n```", status), 3500)
		}
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("*Backup Error*\n`%s`", output))
	}
	return sendConfirm(c.api, msg.ChatID, "backup_now",
		"*Confirm backup?*\n\nThis triggers `systemctl start restic-backup`.")
}

// RestoreCommand lists restic snapshots for restore.
type RestoreCommand struct {
	api *telegram.API
}

func NewRestoreCommand(config *telegram.Config) *RestoreCommand {
	return &RestoreCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *RestoreCommand) Name() string                      { return "restore" }
func (c *RestoreCommand) Description() string               { return "List restic snapshots" }
func (c *RestoreCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *RestoreCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("restic snapshots 2>&1 | head -30 || echo 'restic not available'", 30)
	output = strings.TrimSpace(output)
	if output == "" {
		output = "(no snapshots found)"
	}
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("*Restic Snapshots*\n```%s\n```", output), 3500)
}
