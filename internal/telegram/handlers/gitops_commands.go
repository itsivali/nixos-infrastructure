package handlers

import (
	"context"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/renderer"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type DiffCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewDiffCommand(api *telegram.API, svc *services.Container) *DiffCommand {
	return &DiffCommand{api: api, svc: svc}
}

func (c *DiffCommand) Name() string                      { return "diff" }
func (c *DiffCommand) Description() string               { return "Show flake check results" }
func (c *DiffCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *DiffCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Nix.FlakeCheck()
	if output == "" {
		output = "(no issues found)"
	}
	return c.api.SendLongMessage(msg.ChatID, "*Flake Check*\n"+renderer.CodeBlock(output), 3500)
}

type GitopsReconcileCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewGitopsReconcileCommand(api *telegram.API, svc *services.Container) *GitopsReconcileCommand {
	return &GitopsReconcileCommand{api: api, svc: svc}
}

func (c *GitopsReconcileCommand) Name() string                      { return "reconcile" }
func (c *GitopsReconcileCommand) Description() string               { return "Trigger GitOps reconciliation" }
func (c *GitopsReconcileCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *GitopsReconcileCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:reconcile" {
		if msg.MessageID > 0 {
			_ = c.api.EditMessageMarkdown(msg.ChatID, msg.MessageID, "🔄 Starting reconciliation...")
		} else {
			_ = c.api.SendMarkdown(msg.ChatID, "Starting reconciliation...")
		}
		output := c.svc.GitOps.Reconcile()
		return c.api.SendLongMessage(msg.ChatID, "*Reconciliation*\n"+renderer.CodeBlock(output), 3500)
	}
	return sendConfirm(c.api, msg.ChatID, msg.UserID, "reconcile",
		"*Confirm reconcile?*\n\nThis will pull latest changes, rebuild, and verify.", msg.MessageID)
}

type VerifyCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewVerifyCommand(api *telegram.API, svc *services.Container) *VerifyCommand {
	return &VerifyCommand{api: api, svc: svc}
}

func (c *VerifyCommand) Name() string                      { return "verify" }
func (c *VerifyCommand) Description() string               { return "Verify system configuration" }
func (c *VerifyCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *VerifyCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.GitOps.Verify()
	return c.api.SendLongMessage(msg.ChatID, "*Verification*\n"+renderer.CodeBlock(output), 3500)
}

type GitopsBackupCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewGitopsBackupCommand(api *telegram.API, svc *services.Container) *GitopsBackupCommand {
	return &GitopsBackupCommand{api: api, svc: svc}
}

func (c *GitopsBackupCommand) Name() string                      { return "backup_now" }
func (c *GitopsBackupCommand) Description() string               { return "Trigger restic backup" }
func (c *GitopsBackupCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *GitopsBackupCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:backup_now" {
		if msg.MessageID > 0 {
			_ = c.api.EditMessageMarkdown(msg.ChatID, msg.MessageID, "💾 Starting restic backup...")
		} else {
			_ = c.api.SendMarkdown(msg.ChatID, "Starting restic backup...")
		}
		output, started := c.svc.GitOps.TriggerBackup()
		if started {
			status := c.svc.GitOps.BackupStatus()
			return c.api.SendLongMessage(msg.ChatID, "*Backup Started*\n"+renderer.CodeBlock(status), 3500)
		}
		return c.api.SendMarkdown(msg.ChatID, "*Backup Error*\n`"+strings.TrimSpace(output)+"`")
	}
	return sendConfirm(c.api, msg.ChatID, msg.UserID, "backup_now",
		"*Confirm backup?*\n\nThis triggers `systemctl start restic-backup`.", msg.MessageID)
}

type RestoreCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewRestoreCommand(api *telegram.API, svc *services.Container) *RestoreCommand {
	return &RestoreCommand{api: api, svc: svc}
}

func (c *RestoreCommand) Name() string                      { return "restore" }
func (c *RestoreCommand) Description() string               { return "List restic snapshots" }
func (c *RestoreCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *RestoreCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.GitOps.ListSnapshots()
	if strings.TrimSpace(output) == "" {
		output = "(no snapshots found)"
	}
	return c.api.SendLongMessage(msg.ChatID, "*Restic Snapshots*\n"+renderer.CodeBlock(output), 3500)
}
