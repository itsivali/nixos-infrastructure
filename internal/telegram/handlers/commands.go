package handlers

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/renderer"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

// HelpCommand shows available commands.
type HelpCommand struct {
	bot *telegram.Bot
}

func NewHelpCommand(bot *telegram.Bot) *HelpCommand {
	return &HelpCommand{bot: bot}
}

func (c *HelpCommand) Name() string                      { return "help" }
func (c *HelpCommand) Description() string               { return "Show available commands" }
func (c *HelpCommand) RequiredPermission() telegram.Role { return telegram.RoleGuest }

func (c *HelpCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	cmds := c.bot.GetCommands()
	var lines []string
	lines = append(lines, "*ivali bot — Infrastructure Assistant*")
	lines = append(lines, "")

	for _, cmd := range cmds {
		lines = append(lines, fmt.Sprintf("/%s — %s", cmd.Name(), cmd.Description()))
	}

	return c.bot.API().SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

// StatusCommand shows system status.
type StatusCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewStatusCommand(api *telegram.API, svc *services.Container) *StatusCommand {
	return &StatusCommand{api: api, svc: svc}
}

func (c *StatusCommand) Name() string                      { return "status" }
func (c *StatusCommand) Description() string               { return "Show system status" }
func (c *StatusCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *StatusCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Platform.Status()
	if output == "" {
		output = c.svc.System.Hostname()
	}
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

// HealthCommand shows system health.
type HealthCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewHealthCommand(api *telegram.API, svc *services.Container) *HealthCommand {
	return &HealthCommand{api: api, svc: svc}
}

func (c *HealthCommand) Name() string                      { return "health" }
func (c *HealthCommand) Description() string               { return "Show system health" }
func (c *HealthCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *HealthCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Platform.Doctor()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

// DiskCommand shows disk usage.
type DiskCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewDiskCommand(api *telegram.API, svc *services.Container) *DiskCommand {
	return &DiskCommand{api: api, svc: svc}
}

func (c *DiskCommand) Name() string                      { return "disk" }
func (c *DiskCommand) Description() string               { return "Show disk usage" }
func (c *DiskCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *DiskCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.System.DiskFull()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

// ProcessesCommand shows running processes.
type ProcessesCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewProcessesCommand(api *telegram.API, svc *services.Container) *ProcessesCommand {
	return &ProcessesCommand{api: api, svc: svc}
}

func (c *ProcessesCommand) Name() string                      { return "processes" }
func (c *ProcessesCommand) Description() string               { return "Show top processes" }
func (c *ProcessesCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *ProcessesCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.System.Processes()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

// GenerationsCommand shows NixOS generations.
type GenerationsCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewGenerationsCommand(api *telegram.API, svc *services.Container) *GenerationsCommand {
	return &GenerationsCommand{api: api, svc: svc}
}

func (c *GenerationsCommand) Name() string                      { return "generations" }
func (c *GenerationsCommand) Description() string               { return "Show NixOS generations" }
func (c *GenerationsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *GenerationsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Nix.Generations()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

// sendConfirm asks the user to confirm a destructive action. The prompt is
// bound to the initiating user and expires after confirmationTTL; only the
// same user can confirm it via the confirm: callback.
func sendConfirm(api *telegram.API, chatID int64, userID int, action, text string, messageID int) error {
	RequestConfirmation(userID, chatID, action)
	buttons := []telegram.InlineButton{
		{Text: "✅ Confirm", CallbackData: "confirm:" + action},
		{Text: "❌ Cancel", CallbackData: "cancel"},
	}
	if messageID > 0 {
		return api.EditMessageWithKeyboard(chatID, messageID, text, buttons)
	}
	return api.SendInlineKeyboard(chatID, text, buttons)
}

// RebootCommand reboots the system.
type RebootCommand struct {
	api *telegram.API
}

func NewRebootCommand(api *telegram.API) *RebootCommand {
	return &RebootCommand{api: api}
}

func (c *RebootCommand) Name() string                      { return "reboot" }
func (c *RebootCommand) Description() string               { return "Reboot the system" }
func (c *RebootCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *RebootCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:reboot" {
		if msg.MessageID > 0 {
			_ = c.api.EditMessageMarkdown(msg.ChatID, msg.MessageID, "🔄 Rebooting...")
		} else {
			_ = c.api.SendMarkdown(msg.ChatID, "Rebooting...")
		}
		svc := services.NewRunner()
		svc.Run("sudo reboot", 5)
		return nil
	}
	return sendConfirm(c.api, msg.ChatID, msg.UserID, "reboot",
		"*Confirm reboot?*\n\nThe system will reboot immediately.", msg.MessageID)
}

// ShutdownCommand shuts down the system.
type ShutdownCommand struct {
	api *telegram.API
}

func NewShutdownCommand(api *telegram.API) *ShutdownCommand {
	return &ShutdownCommand{api: api}
}

func (c *ShutdownCommand) Name() string                      { return "shutdown" }
func (c *ShutdownCommand) Description() string               { return "Shut down the system" }
func (c *ShutdownCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *ShutdownCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:shutdown" {
		if msg.MessageID > 0 {
			_ = c.api.EditMessageMarkdown(msg.ChatID, msg.MessageID, "⏻ Shutting down...")
		} else {
			_ = c.api.SendMarkdown(msg.ChatID, "Shutting down...")
		}
		svc := services.NewRunner()
		svc.Run("sudo shutdown -h now", 5)
		return nil
	}
	return sendConfirm(c.api, msg.ChatID, msg.UserID, "shutdown",
		"*Confirm shutdown?*\n\nThe system will power off immediately.", msg.MessageID)
}

// DeployCommand triggers a NixOS rebuild.
type DeployCommand struct {
	api    *telegram.API
	config *telegram.Config
	svc    *services.Container
}

func NewDeployCommand(api *telegram.API, config *telegram.Config, svc *services.Container) *DeployCommand {
	return &DeployCommand{api: api, config: config, svc: svc}
}

func (c *DeployCommand) Name() string                      { return "deploy" }
func (c *DeployCommand) Description() string               { return "Rebuild NixOS configuration" }
func (c *DeployCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *DeployCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:deploy" {
		if msg.MessageID > 0 {
			_ = c.api.EditMessageMarkdown(msg.ChatID, msg.MessageID, "🚀 Starting NixOS rebuild...")
		} else {
			_ = c.api.SendMarkdown(msg.ChatID, "Starting NixOS rebuild...")
		}
		output := c.svc.Nix.Rebuild("")
		return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
	}
	host, _ := os.Hostname()
	return sendConfirm(c.api, msg.ChatID, msg.UserID, "deploy",
		fmt.Sprintf("*Confirm deploy?*\n\nThis runs `nixos-rebuild switch --flake .#%s`.", host), msg.MessageID)
}

// RollbackCommand rolls back to the previous generation.
type RollbackCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewRollbackCommand(api *telegram.API, svc *services.Container) *RollbackCommand {
	return &RollbackCommand{api: api, svc: svc}
}

func (c *RollbackCommand) Name() string                      { return "rollback" }
func (c *RollbackCommand) Description() string               { return "Rollback to previous generation" }
func (c *RollbackCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *RollbackCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:rollback" {
		if msg.MessageID > 0 {
			_ = c.api.EditMessageMarkdown(msg.ChatID, msg.MessageID, "⏪ Rolling back...")
		} else {
			_ = c.api.SendMarkdown(msg.ChatID, "Rolling back...")
		}
		output := c.svc.Nix.RebuildWithRollback()
		return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
	}
	return sendConfirm(c.api, msg.ChatID, msg.UserID, "rollback",
		"*Confirm rollback?*\n\nThis activates the previous NixOS generation.", msg.MessageID)
}

// UpdateCommand pulls and updates flake inputs.
type UpdateCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewUpdateCommand(api *telegram.API, svc *services.Container) *UpdateCommand {
	return &UpdateCommand{api: api, svc: svc}
}

func (c *UpdateCommand) Name() string                      { return "update" }
func (c *UpdateCommand) Description() string               { return "Update flake inputs" }
func (c *UpdateCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *UpdateCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "Updating flake inputs...")
	output := c.svc.Nix.FlakeUpdate()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

// ScanCommand scans the repository.
type ScanCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewScanCommand(api *telegram.API, svc *services.Container) *ScanCommand {
	return &ScanCommand{api: api, svc: svc}
}

func (c *ScanCommand) Name() string                      { return "scan" }
func (c *ScanCommand) Description() string               { return "Scan repository modules" }
func (c *ScanCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *ScanCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Platform.Scan()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

// SecurityCommand shows security status.
type SecurityCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewSecurityCommand(api *telegram.API, svc *services.Container) *SecurityCommand {
	return &SecurityCommand{api: api, svc: svc}
}

func (c *SecurityCommand) Name() string                      { return "security" }
func (c *SecurityCommand) Description() string               { return "Show security status" }
func (c *SecurityCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *SecurityCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	result := c.svc.Security.FullScan()
	return c.api.SendMarkdown(msg.ChatID, strings.Join(result.Lines, "\n"))
}

// DoctorCommand runs system diagnostics.
type DoctorCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewDoctorCommand(api *telegram.API, svc *services.Container) *DoctorCommand {
	return &DoctorCommand{api: api, svc: svc}
}

func (c *DoctorCommand) Name() string                      { return "doctor" }
func (c *DoctorCommand) Description() string               { return "Run system diagnostics" }
func (c *DoctorCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *DoctorCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Platform.Doctor()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

// StoreCommand shows Nix store usage.
type StoreCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewStoreCommand(api *telegram.API, svc *services.Container) *StoreCommand {
	return &StoreCommand{api: api, svc: svc}
}

func (c *StoreCommand) Name() string                      { return "store" }
func (c *StoreCommand) Description() string               { return "Show Nix store usage" }
func (c *StoreCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *StoreCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	roots, disk := c.svc.Nix.StoreSize()
	return c.api.SendMarkdown(msg.ChatID, renderer.BuildCard(renderer.Card{
		Title: "Nix Store",
		Lines: []string{
			renderer.KeyValue("Root links", roots),
			renderer.KeyValue("Disk usage", disk),
		},
	}))
}

// GCCommand runs Nix garbage collection.
type GCCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewGCCommand(api *telegram.API, svc *services.Container) *GCCommand {
	return &GCCommand{api: api, svc: svc}
}

func (c *GCCommand) Name() string                      { return "gc" }
func (c *GCCommand) Description() string               { return "Run Nix garbage collection" }
func (c *GCCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *GCCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:gc" {
		if msg.MessageID > 0 {
			_ = c.api.EditMessageMarkdown(msg.ChatID, msg.MessageID, "♻️ Running garbage collection...")
		} else {
			_ = c.api.SendMarkdown(msg.ChatID, "Running garbage collection...")
		}
		output := c.svc.Nix.GarbageCollect()
		return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
	}
	return sendConfirm(c.api, msg.ChatID, msg.UserID, "gc",
		"*Confirm garbage collection?*\n\nThis will remove unused Nix store paths.", msg.MessageID)
}
