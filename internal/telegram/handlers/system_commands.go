package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/renderer"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type NixCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewNixCommand(api *telegram.API, svc *services.Container) *NixCommand {
	return &NixCommand{api: api, svc: svc}
}

func (c *NixCommand) Name() string                      { return "nix" }
func (c *NixCommand) Description() string               { return "Nix operations" }
func (c *NixCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *NixCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/nix <command>`")
	}
	output := c.svc.Nix.NixCommand(strings.Fields(args)...)
	if output == "" {
		output = "(no output)"
	}
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type RunCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewRunCommand(api *telegram.API, svc *services.Container) *RunCommand {
	return &RunCommand{api: api, svc: svc}
}

func (c *RunCommand) Name() string                      { return "run" }
func (c *RunCommand) Description() string               { return "Execute shell command" }
func (c *RunCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *RunCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/run <command>`")
	}
	output := c.svc.Runner.RunArgs(120, strings.Fields(args)...)
	if output == "" {
		output = "(no output)"
	}
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type PkgCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewPkgCommand(api *telegram.API, svc *services.Container) *PkgCommand {
	return &PkgCommand{api: api, svc: svc}
}

func (c *PkgCommand) Name() string                      { return "pkg" }
func (c *PkgCommand) Description() string               { return "Package information" }
func (c *PkgCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *PkgCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		output := c.svc.Nix.PkgInfo("")
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Installed packages: %s", output))
	}
	output := c.svc.Nix.PkgInfo(args)
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type SpeedtestCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewSpeedtestCommand(api *telegram.API, svc *services.Container) *SpeedtestCommand {
	return &SpeedtestCommand{api: api, svc: svc}
}

func (c *SpeedtestCommand) Name() string                      { return "speedtest" }
func (c *SpeedtestCommand) Description() string               { return "Run speed test" }
func (c *SpeedtestCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *SpeedtestCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "Running speed test...")
	output := c.svc.Runner.Run(
		"curl -s -w '\\nSpeed: %{speed_download} bytes/sec\\nTime: %{time_total}s\\n' -o /dev/null http://speedtest.tele2.net/10MB.zip 2>/dev/null || echo 'Speed test failed'", 60)
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type TopCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewTopCommand(api *telegram.API, svc *services.Container) *TopCommand {
	return &TopCommand{api: api, svc: svc}
}

func (c *TopCommand) Name() string                      { return "top" }
func (c *TopCommand) Description() string               { return "Show system metrics" }
func (c *TopCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *TopCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	uptime, memory, disk := c.svc.System.TopMetrics()
	return c.api.SendMarkdown(msg.ChatID, renderer.BuildCard(renderer.Card{
		Title: "System Metrics",
		Lines: []string{
			renderer.KeyValue("Uptime", uptime),
			"*Memory:*\n" + renderer.CodeBlock(memory),
			renderer.KeyValue("Disk", disk),
		},
	}))
}

type LogCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewLogCommand(api *telegram.API, svc *services.Container) *LogCommand {
	return &LogCommand{api: api, svc: svc}
}

func (c *LogCommand) Name() string                      { return "log" }
func (c *LogCommand) Description() string               { return "Show system logs" }
func (c *LogCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *LogCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.System.Journal()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type MetricsCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewMetricsCommand(api *telegram.API, svc *services.Container) *MetricsCommand {
	return &MetricsCommand{api: api, svc: svc}
}

func (c *MetricsCommand) Name() string                      { return "metrics" }
func (c *MetricsCommand) Description() string               { return "Show Prometheus metrics" }
func (c *MetricsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *MetricsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Prometheus Metrics*")
	lines = append(lines, "")

	services := c.svc.Monitoring.PrometheusServices()
	if services != "" && !strings.Contains(services, "not available") {
		lines = append(lines, "*Service Health:*")
		lines = append(lines, services)
		lines = append(lines, "")
	}

	if cpu := c.svc.Monitoring.CPUUsage(); cpu != "" && cpu != "null" {
		lines = append(lines, renderer.KeyValue("CPU Usage", cpu+"%"))
	}
	if mem := c.svc.Monitoring.MemoryUsage(); mem != "" && mem != "null" {
		lines = append(lines, renderer.KeyValue("Memory Usage", mem+"%"))
	}
	if disk := c.svc.Monitoring.DiskUsage(); disk != "" && disk != "null" {
		lines = append(lines, renderer.KeyValue("Disk Usage /", disk+"%"))
	}
	if load := c.svc.Monitoring.SystemLoad(); load != "" && load != "null" {
		lines = append(lines, renderer.KeyValue("System Load (1m)", load))
	}

	if len(lines) == 1 {
		lines = append(lines, "`Prometheus not available or no metrics found.`")
	}

	return c.api.SendLongMessage(msg.ChatID, strings.Join(lines, "\n"), 3500)
}

type UsersCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewUsersCommand(api *telegram.API, svc *services.Container) *UsersCommand {
	return &UsersCommand{api: api, svc: svc}
}

func (c *UsersCommand) Name() string                      { return "sysusers" }
func (c *UsersCommand) Description() string               { return "List system users" }
func (c *UsersCommand) RequiredPermission() telegram.Role { return telegram.RoleOwner }

func (c *UsersCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Runner.Run("getent passwd | cut -d: -f1,6 | grep -v '/nix/store' | head -20", 5)
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type AddUserCommand struct {
	api *telegram.API
}

func NewAddUserCommand(api *telegram.API) *AddUserCommand {
	return &AddUserCommand{api: api}
}

func (c *AddUserCommand) Name() string                      { return "adduser" }
func (c *AddUserCommand) Description() string               { return "Add a system user" }
func (c *AddUserCommand) RequiredPermission() telegram.Role { return telegram.RoleOwner }

func (c *AddUserCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	return c.api.SendMarkdown(msg.ChatID, "User management is handled via NixOS configuration in hosts/hosts.nix")
}

type RmUserCommand struct {
	api *telegram.API
}

func NewRmUserCommand(api *telegram.API) *RmUserCommand {
	return &RmUserCommand{api: api}
}

func (c *RmUserCommand) Name() string                      { return "rmuser" }
func (c *RmUserCommand) Description() string               { return "Remove a system user" }
func (c *RmUserCommand) RequiredPermission() telegram.Role { return telegram.RoleOwner }

func (c *RmUserCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	return c.api.SendMarkdown(msg.ChatID, "User management is handled via NixOS configuration in hosts/hosts.nix")
}

type MenuCommand struct {
	api *telegram.API
}

func NewMenuCommand(api *telegram.API) *MenuCommand {
	return &MenuCommand{api: api}
}

func (c *MenuCommand) Name() string                      { return "menu" }
func (c *MenuCommand) Description() string               { return "Show main menu" }
func (c *MenuCommand) RequiredPermission() telegram.Role { return telegram.RoleGuest }

func (c *MenuCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	menu := `*ivali bot — Main Menu*

*System:* /status /health /metrics /disk /processes /top
*Operations:* /deploy /rollback /reboot /shutdown /update /cancel
*Desktop:* /open /apps /screenshot /clipboard /volume /brightness
*Development:* /git /github /gitlab /nix /run /scan /doctor
*Help:* /help /menu

Tap a button below or type a command.`
	rows := menuRows()
	return c.api.SendReplyKeyboard(msg.ChatID, menu, rows)
}

func menuRows() [][]string {
	return [][]string{
		{"🖥 /status", "💓 /health", "📊 /metrics", "💽 /disk"},
		{"⚙️ /processes", "📈 /top", "🚀 /deploy", "⏪ /rollback"},
		{"🔄 /reboot", "🔌 /shutdown", "⬆️ /update", "✋ /cancel"},
		{"🖼 /open", "📱 /apps", "📸 /screenshot", "📋 /clipboard"},
		{"🔊 /volume", "🔆 /brightness", "🖥️ /windows", "🗔 /workspace"},
		{"🌐 /git", "🐙 /github", "🦊 /gitlab", "⚡ /nix"},
		{"▶️ /run", "🔍 /scan", "🩺 /doctor", "📦 /store"},
		{"🗑 /gc", "🔔 /notify", "❓ /help", "📖 /menu"},
	}
}

type StartCommand struct {
	api *telegram.API
}

func NewStartCommand(api *telegram.API) *StartCommand {
	return &StartCommand{api: api}
}

func (c *StartCommand) Name() string                      { return "start" }
func (c *StartCommand) Description() string               { return "Show welcome message" }
func (c *StartCommand) RequiredPermission() telegram.Role { return telegram.RoleGuest }

func (c *StartCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	welcome := `*Welcome to ivali bot!* 🤖

I'm your NixOS infrastructure assistant.
I can help you manage your system remotely.

Type /help to see available commands.
Type /menu for the main menu.`
	rows := menuRows()
	return c.api.SendReplyKeyboard(msg.ChatID, welcome, rows)
}

type NotifyCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewNotifyCommand(api *telegram.API, svc *services.Container) *NotifyCommand {
	return &NotifyCommand{api: api, svc: svc}
}

func (c *NotifyCommand) Name() string                      { return "notify" }
func (c *NotifyCommand) Description() string               { return "Send notification" }
func (c *NotifyCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *NotifyCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/notify <message>`")
	}
	c.svc.System.Notify(args)
	return c.api.SendMarkdown(msg.ChatID, "Notification sent")
}
