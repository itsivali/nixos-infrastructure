package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/security"
	"github.com/itsivali/nixos-infrastructure/internal/telegram"
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
}

func NewStatusCommand(config *telegram.Config) *StatusCommand {
	return &StatusCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *StatusCommand) Name() string                      { return "status" }
func (c *StatusCommand) Description() string               { return "Show system status" }
func (c *StatusCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *StatusCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("ivali status 2>&1 || echo 'ivali not available'", 30)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// HealthCommand shows system health.
type HealthCommand struct {
	api *telegram.API
}

func NewHealthCommand(config *telegram.Config) *HealthCommand {
	return &HealthCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *HealthCommand) Name() string                      { return "health" }
func (c *HealthCommand) Description() string               { return "Show system health" }
func (c *HealthCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *HealthCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("ivali health 2>&1 || echo 'ivali not available'", 30)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// DiskCommand shows disk usage.
type DiskCommand struct {
	api *telegram.API
}

func NewDiskCommand(config *telegram.Config) *DiskCommand {
	return &DiskCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *DiskCommand) Name() string                      { return "disk" }
func (c *DiskCommand) Description() string               { return "Show disk usage" }
func (c *DiskCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *DiskCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("df -h / /boot 2>/dev/null", 10)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// ProcessesCommand shows running processes.
type ProcessesCommand struct {
	api *telegram.API
}

func NewProcessesCommand(config *telegram.Config) *ProcessesCommand {
	return &ProcessesCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *ProcessesCommand) Name() string                      { return "processes" }
func (c *ProcessesCommand) Description() string               { return "Show top processes" }
func (c *ProcessesCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *ProcessesCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("ps aux --sort=-%cpu | head -11", 5)
	if output == "" {
		output = runCmd("ps aux | head -11", 5)
	}
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// GenerationsCommand shows NixOS generations.
type GenerationsCommand struct {
	api *telegram.API
}

func NewGenerationsCommand(config *telegram.Config) *GenerationsCommand {
	return &GenerationsCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *GenerationsCommand) Name() string                      { return "generations" }
func (c *GenerationsCommand) Description() string               { return "Show NixOS generations" }
func (c *GenerationsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *GenerationsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("sudo nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -10", 30)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// sendConfirm asks the user to confirm a destructive action via an inline
// keyboard. The buttons carry CallbackData "confirm:<action>" / "cancel",
// which are routed by the bot's callback handler.
func sendConfirm(api *telegram.API, chatID int64, action, text string) error {
	buttons := []telegram.InlineButton{
		{Text: "✅ Confirm", CallbackData: "confirm:" + action},
		{Text: "❌ Cancel", CallbackData: "cancel"},
	}
	return api.SendInlineKeyboard(chatID, text, buttons)
}

// RebootCommand reboots the system.
type RebootCommand struct {
	api *telegram.API
}

func NewRebootCommand(config *telegram.Config) *RebootCommand {
	return &RebootCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *RebootCommand) Name() string                      { return "reboot" }
func (c *RebootCommand) Description() string               { return "Reboot the system" }
func (c *RebootCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *RebootCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:reboot" {
		_ = runCmd("sudo reboot", 5)
		return c.api.SendMarkdown(msg.ChatID, "Rebooting...")
	}
	return sendConfirm(c.api, msg.ChatID, "reboot",
		"*Confirm reboot?*\n\nThe system will reboot immediately.")
}

// ShutdownCommand shuts down the system.
type ShutdownCommand struct {
	api *telegram.API
}

func NewShutdownCommand(config *telegram.Config) *ShutdownCommand {
	return &ShutdownCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *ShutdownCommand) Name() string                      { return "shutdown" }
func (c *ShutdownCommand) Description() string               { return "Shut down the system" }
func (c *ShutdownCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *ShutdownCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:shutdown" {
		_ = runCmd("sudo shutdown -h now", 5)
		return c.api.SendMarkdown(msg.ChatID, "Shutting down...")
	}
	return sendConfirm(c.api, msg.ChatID, "shutdown",
		"*Confirm shutdown?*\n\nThe system will power off immediately.")
}

// DeployCommand triggers a NixOS rebuild.
type DeployCommand struct {
	api *telegram.API
}

func NewDeployCommand(config *telegram.Config) *DeployCommand {
	return &DeployCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *DeployCommand) Name() string                      { return "deploy" }
func (c *DeployCommand) Description() string               { return "Rebuild NixOS configuration" }
func (c *DeployCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *DeployCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:deploy" {
		_ = c.api.SendMarkdown(msg.ChatID, "Starting NixOS rebuild...")
		output := runCmd("sudo nixos-rebuild switch --flake /home/ivali/nixos-infrastructure#prague 2>&1", 600)
		return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
	}
	return sendConfirm(c.api, msg.ChatID, "deploy",
		"*Confirm deploy?*\n\nThis runs `nixos-rebuild switch --flake .#prague`.")
}

// RollbackCommand rolls back to the previous generation.
type RollbackCommand struct {
	api *telegram.API
}

func NewRollbackCommand(config *telegram.Config) *RollbackCommand {
	return &RollbackCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *RollbackCommand) Name() string                      { return "rollback" }
func (c *RollbackCommand) Description() string               { return "Rollback to previous generation" }
func (c *RollbackCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *RollbackCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback && msg.CallbackData() == "confirm:rollback" {
		_ = c.api.SendMarkdown(msg.ChatID, "Rolling back...")
		output := runCmd("sudo nixos-rebuild switch --rollback 2>&1", 300)
		return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
	}
	return sendConfirm(c.api, msg.ChatID, "rollback",
		"*Confirm rollback?*\n\nThis activates the previous NixOS generation.")
}

// UpdateCommand pulls and updates flake inputs.
type UpdateCommand struct {
	api *telegram.API
}

func NewUpdateCommand(config *telegram.Config) *UpdateCommand {
	return &UpdateCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *UpdateCommand) Name() string                      { return "update" }
func (c *UpdateCommand) Description() string               { return "Update flake inputs" }
func (c *UpdateCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *UpdateCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "Updating flake inputs...")
	output := runCmd("cd /home/ivali/nixos-infrastructure && git pull && nix flake update 2>&1", 120)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// ScanCommand scans the repository.
type ScanCommand struct {
	api *telegram.API
}

func NewScanCommand(config *telegram.Config) *ScanCommand {
	return &ScanCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *ScanCommand) Name() string                      { return "scan" }
func (c *ScanCommand) Description() string               { return "Scan repository modules" }
func (c *ScanCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *ScanCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("ivali scan 2>&1 || echo 'ivali not available'", 30)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// SecurityCommand shows security status.
type SecurityCommand struct {
	api *telegram.API
}

func NewSecurityCommand(config *telegram.Config) *SecurityCommand {
	return &SecurityCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *SecurityCommand) Name() string                      { return "security" }
func (c *SecurityCommand) Description() string               { return "Show security status" }
func (c *SecurityCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *SecurityCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	result, err := security.RunFullScan()
	if err != nil {
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("*Security scan failed:* `%s`", err))
	}

	var lines []string
	lines = append(lines, "*Security Status*")
	lines = append(lines, "")

	for _, cat := range result.Categories {
		icon := "✅"
		if !cat.Pass {
			icon = "❌"
		}
		lines = append(lines, fmt.Sprintf("*%s %s*", icon, strings.Title(cat.Name)))
		for _, check := range cat.Checks {
			checkIcon := "  ✅"
			if !check.Pass {
				if check.Severity == "critical" || check.Severity == "high" {
					checkIcon = "  ❌"
				} else {
					checkIcon = "  ⚠️"
				}
			}
			lines = append(lines, fmt.Sprintf("%s %s: `%s`", checkIcon, check.Name, check.Message))
		}
		lines = append(lines, "")
	}

	lines = append(lines, fmt.Sprintf("_Score: %s_", security.ScoreFromResult(result)))

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

// DoctorCommand runs system diagnostics.
type DoctorCommand struct {
	api *telegram.API
}

func NewDoctorCommand(config *telegram.Config) *DoctorCommand {
	return &DoctorCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *DoctorCommand) Name() string                      { return "doctor" }
func (c *DoctorCommand) Description() string               { return "Run system diagnostics" }
func (c *DoctorCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *DoctorCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("ivali doctor 2>&1 || echo 'ivali not available'", 60)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// StoreCommand shows Nix store usage.
type StoreCommand struct {
	api *telegram.API
}

func NewStoreCommand(config *telegram.Config) *StoreCommand {
	return &StoreCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *StoreCommand) Name() string                      { return "store" }
func (c *StoreCommand) Description() string               { return "Show Nix store usage" }
func (c *StoreCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *StoreCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("nix-store -q --size-roots /nix/store 2>/dev/null || echo 'nix-store not available'", 30)
	output2 := runCmd("du -sh /nix/store 2>/dev/null || echo 'unknown'", 30)
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("*Nix Store*\n\nRoot links: `%s`\nDisk usage: `%s`", output, output2))
}

// GCCommand runs Nix garbage collection.
type GCCommand struct {
	api *telegram.API
}

func NewGCCommand(config *telegram.Config) *GCCommand {
	return &GCCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *GCCommand) Name() string                      { return "gc" }
func (c *GCCommand) Description() string               { return "Run Nix garbage collection" }
func (c *GCCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *GCCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "Running garbage collection...")
	output := runCmd("sudo nix-collect-garbage -d 2>&1", 300)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// process command stubs
