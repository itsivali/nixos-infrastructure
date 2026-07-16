package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/willisivali/nixos-infrastructure/internal/telegram"
)

// System commands — Nix, packages, diagnostics, and user management.

type NixCommand struct {
	api *telegram.API
}

func NewNixCommand(config *telegram.Config) *NixCommand {
	return &NixCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *NixCommand) Name() string             { return "nix" }
func (c *NixCommand) Description() string       { return "Nix operations" }
func (c *NixCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *NixCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/nix <command>`")
	}
	output := runCmd(fmt.Sprintf("nix %s 2>&1", args), 120)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type RunCommand struct {
	api *telegram.API
}

func NewRunCommand(config *telegram.Config) *RunCommand {
	return &RunCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *RunCommand) Name() string             { return "run" }
func (c *RunCommand) Description() string       { return "Execute shell command" }
func (c *RunCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *RunCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/run <command>`")
	}
	output := runCmd(args, 120)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type PkgCommand struct {
	api *telegram.API
}

func NewPkgCommand(config *telegram.Config) *PkgCommand {
	return &PkgCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *PkgCommand) Name() string             { return "pkg" }
func (c *PkgCommand) Description() string       { return "Package information" }
func (c *PkgCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *PkgCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		output := runCmd("nix-env -q 2>/dev/null | wc -l", 10)
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Installed packages: %s", output))
	}
	output := runCmd(fmt.Sprintf("nix-env -q %s 2>/dev/null || echo 'Package not found'", args), 30)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type SpeedtestCommand struct {
	api *telegram.API
}

func NewSpeedtestCommand(config *telegram.Config) *SpeedtestCommand {
	return &SpeedtestCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *SpeedtestCommand) Name() string             { return "speedtest" }
func (c *SpeedtestCommand) Description() string       { return "Run speed test" }
func (c *SpeedtestCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *SpeedtestCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "Running speed test...")
	output := runCmd("curl -s -w '\\nSpeed: %{speed_download} bytes/sec\\nTime: %{time_total}s\\n' -o /dev/null http://speedtest.tele2.net/10MB.zip 2>/dev/null || echo 'Speed test failed'", 60)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type TopCommand struct {
	api *telegram.API
}

func NewTopCommand(config *telegram.Config) *TopCommand {
	return &TopCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *TopCommand) Name() string             { return "top" }
func (c *TopCommand) Description() string       { return "Show system metrics" }
func (c *TopCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *TopCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*System Metrics*")
	lines = append(lines, "")

	output := runCmd("uptime", 5)
	lines = append(lines, fmt.Sprintf("*Uptime:* `%s`", output))

	output = runCmd("free -h | head -2", 5)
	lines = append(lines, fmt.Sprintf("*Memory:*\n```\n%s\n```", output))

	output = runCmd("df -h / | tail -1", 5)
	lines = append(lines, fmt.Sprintf("*Disk:* `%s`", output))

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

type LogCommand struct {
	api *telegram.API
}

func NewLogCommand(config *telegram.Config) *LogCommand {
	return &LogCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *LogCommand) Name() string             { return "log" }
func (c *LogCommand) Description() string       { return "Show system logs" }
func (c *LogCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *LogCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("journalctl -u ivali-bot -n 20 --no-pager 2>/dev/null || journalctl -n 20 --no-pager", 10)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type BackupCommand struct {
	api *telegram.API
}

func NewBackupCommand(config *telegram.Config) *BackupCommand {
	return &BackupCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *BackupCommand) Name() string             { return "backup" }
func (c *BackupCommand) Description() string       { return "Trigger backup" }
func (c *BackupCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *BackupCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "Backup not yet implemented")
	return nil
}

type MetricsCommand struct {
	api *telegram.API
}

func NewMetricsCommand(config *telegram.Config) *MetricsCommand {
	return &MetricsCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *MetricsCommand) Name() string             { return "metrics" }
func (c *MetricsCommand) Description() string       { return "Show Prometheus metrics" }
func (c *MetricsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *MetricsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("curl -s http://127.0.0.1:9090/api/v1/query?query=up 2>/dev/null | jq -r '.data.result[] | \"\\(.metric.job): \\(.value[1])\"' 2>/dev/null || echo 'Prometheus not available'", 10)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type CancelCommand struct {
	api *telegram.API
}

func NewCancelCommand(config *telegram.Config) *CancelCommand {
	return &CancelCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *CancelCommand) Name() string             { return "cancel" }
func (c *CancelCommand) Description() string       { return "Cancel pending operations" }
func (c *CancelCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *CancelCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	return c.api.SendMarkdown(msg.ChatID, "No pending operations to cancel")
}

// User management — delegated to NixOS declarative config.

type UsersCommand struct {
	api *telegram.API
}

func NewUsersCommand(config *telegram.Config) *UsersCommand {
	return &UsersCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *UsersCommand) Name() string             { return "users" }
func (c *UsersCommand) Description() string       { return "List system users" }
func (c *UsersCommand) RequiredPermission() telegram.Role { return telegram.RoleOwner }

func (c *UsersCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("getent passwd | cut -d: -f1,6 | grep -v '/nix/store' | head -20", 5)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type AddUserCommand struct {
	api *telegram.API
}

func NewAddUserCommand(config *telegram.Config) *AddUserCommand {
	return &AddUserCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *AddUserCommand) Name() string             { return "adduser" }
func (c *AddUserCommand) Description() string       { return "Add a system user" }
func (c *AddUserCommand) RequiredPermission() telegram.Role { return telegram.RoleOwner }

func (c *AddUserCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	return c.api.SendMarkdown(msg.ChatID, "User management is handled via NixOS configuration in hosts/hosts.nix")
}

type RmUserCommand struct {
	api *telegram.API
}

func NewRmUserCommand(config *telegram.Config) *RmUserCommand {
	return &RmUserCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *RmUserCommand) Name() string             { return "rmuser" }
func (c *RmUserCommand) Description() string       { return "Remove a system user" }
func (c *RmUserCommand) RequiredPermission() telegram.Role { return telegram.RoleOwner }

func (c *RmUserCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	return c.api.SendMarkdown(msg.ChatID, "User management is handled via NixOS configuration in hosts/hosts.nix")
}

// Navigation — menus and entry points.

type MenuCommand struct {
	api *telegram.API
}

func NewMenuCommand(config *telegram.Config) *MenuCommand {
	return &MenuCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *MenuCommand) Name() string             { return "menu" }
func (c *MenuCommand) Description() string       { return "Show main menu" }
func (c *MenuCommand) RequiredPermission() telegram.Role { return telegram.RoleGuest }

func (c *MenuCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	menu := `*ivali bot — Main Menu*

*System:*
/status /health /metrics /disk /processes /top

*Operations:*
/deploy /rollback /reboot /shutdown /update

*Desktop:*
/open /apps /screenshot /clipboard /volume /brightness

*Development:*
/git /github /gitlab /nix /scan /doctor

*Help:*
/help /menu`
	return c.api.SendMarkdown(msg.ChatID, menu)
}

type StartCommand struct {
	api *telegram.API
}

func NewStartCommand(config *telegram.Config) *StartCommand {
	return &StartCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *StartCommand) Name() string             { return "start" }
func (c *StartCommand) Description() string       { return "Show welcome message" }
func (c *StartCommand) RequiredPermission() telegram.Role { return telegram.RoleGuest }

func (c *StartCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	welcome := `*Welcome to ivali bot!*

I'm your NixOS infrastructure assistant.
I can help you manage your system remotely.

Type /help to see available commands.
Type /menu for the main menu.`
	return c.api.SendMarkdown(msg.ChatID, welcome)
}

type NotifyCommand struct {
	api *telegram.API
}

func NewNotifyCommand(config *telegram.Config) *NotifyCommand {
	return &NotifyCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *NotifyCommand) Name() string             { return "notify" }
func (c *NotifyCommand) Description() string       { return "Send notification" }
func (c *NotifyCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *NotifyCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/notify <message>`")
	}
	runCmd(fmt.Sprintf("notify-send 'Bot' '%s'", args), 5)
	return c.api.SendMarkdown(msg.ChatID, "Notification sent")
}
