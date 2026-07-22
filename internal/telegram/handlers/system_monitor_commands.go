package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/willisivali/nixos-infrastructure/internal/telegram"
)

// UptimeCommand shows system uptime.
type UptimeCommand struct {
	api *telegram.API
}

func NewUptimeCommand(config *telegram.Config) *UptimeCommand {
	return &UptimeCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *UptimeCommand) Name() string                      { return "uptime" }
func (c *UptimeCommand) Description() string               { return "Show system uptime" }
func (c *UptimeCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *UptimeCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("uptime -p 2>/dev/null || uptime", 5)
	output = strings.TrimSpace(output)
	if output == "" {
		return c.api.SendMarkdown(msg.ChatID, "Failed to retrieve uptime.")
	}
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("*System Uptime*\n\n`%s`", output))
}

// MemoryCommand shows memory usage.
type MemoryCommand struct {
	api *telegram.API
}

func NewMemoryCommand(config *telegram.Config) *MemoryCommand {
	return &MemoryCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *MemoryCommand) Name() string                      { return "memory" }
func (c *MemoryCommand) Description() string               { return "Show memory usage" }
func (c *MemoryCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *MemoryCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Memory Usage*")
	lines = append(lines, "")

	raw := runCmd("free -h", 5)
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return c.api.SendMarkdown(msg.ChatID, "Failed to retrieve memory info.")
	}

	memLine := ""
	swapLine := ""
	for _, row := range strings.Split(raw, "\n") {
		fields := strings.Fields(row)
		if len(fields) < 2 {
			continue
		}
		switch fields[0] {
		case "Mem:":
			memLine = fmt.Sprintf("*Total:* `%s`  *Used:* `%s`  *Free:* `%s`  *Avail:* `%s`",
				fields[1], fields[2], fields[3], fields[6])
		case "Swap:":
			swapLine = fmt.Sprintf("*Swap Total:* `%s`  *Used:* `%s`  *Free:* `%s`",
				fields[1], fields[2], fields[3])
		}
	}

	if memLine != "" {
		lines = append(lines, memLine)
	}
	if swapLine != "" {
		lines = append(lines, "")
		lines = append(lines, swapLine)
	}

	lines = append(lines, "")
	lines = append(lines, "```")
	lines = append(lines, raw)
	lines = append(lines, "```")

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

// CPUCommand shows CPU load and core count.
type CPUCommand struct {
	api *telegram.API
}

func NewCPUCommand(config *telegram.Config) *CPUCommand {
	return &CPUCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *CPUCommand) Name() string                      { return "cpu" }
func (c *CPUCommand) Description() string               { return "Show CPU load" }
func (c *CPUCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *CPUCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*CPU Status*")
	lines = append(lines, "")

	loadAvg := runCmd("cat /proc/loadavg 2>/dev/null", 5)
	loadAvg = strings.TrimSpace(loadAvg)
	if loadAvg == "" {
		return c.api.SendMarkdown(msg.ChatID, "Failed to retrieve CPU info.")
	}

	parts := strings.Fields(loadAvg)
	if len(parts) >= 3 {
		lines = append(lines, "*Load averages (1/5/15 min):*")
		lines = append(lines, fmt.Sprintf("  1 min:  `%s`", parts[0]))
		lines = append(lines, fmt.Sprintf("  5 min:  `%s`", parts[1]))
		lines = append(lines, fmt.Sprintf("  15 min: `%s`", parts[2]))
	}

	cores := runCmd("nproc 2>/dev/null || echo unknown", 5)
	cores = strings.TrimSpace(cores)
	lines = append(lines, "")
	lines = append(lines, fmt.Sprintf("*CPU cores:* `%s`", cores))

	model := runCmd("grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs", 5)
	model = strings.TrimSpace(model)
	if model != "" {
		lines = append(lines, fmt.Sprintf("*Model:* `%s`", model))
	}

	lines = append(lines, "")
	lines = append(lines, "```")
	lines = append(lines, loadAvg)
	lines = append(lines, "```")

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

// UpdatesCommand shows NixOS update information.
type UpdatesCommand struct {
	api *telegram.API
}

func NewUpdatesCommand(config *telegram.Config) *UpdatesCommand {
	return &UpdatesCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *UpdatesCommand) Name() string                      { return "updates" }
func (c *UpdatesCommand) Description() string               { return "Show update status" }
func (c *UpdatesCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *UpdatesCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Update Status*")
	lines = append(lines, "")

	_ = c.api.SendMarkdown(msg.ChatID, "Checking update status...")

	pkgCount := runCmd("nix-store -q --requisites /run/current-system 2>/dev/null | wc -l", 30)
	pkgCount = strings.TrimSpace(pkgCount)
	if pkgCount == "" {
		pkgCount = "unknown"
	}
	lines = append(lines, fmt.Sprintf("*Installed system packages:* `%s`", pkgCount))

	gen := runCmd("nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -1", 10)
	gen = strings.TrimSpace(gen)
	if gen != "" {
		lines = append(lines, fmt.Sprintf("*Current generation:* `%s`", gen))
	}

	repoStatus := runCmd("cd /home/ivali/nixos-infrastructure && git status --short 2>/dev/null | head -5", 5)
	repoStatus = strings.TrimSpace(repoStatus)
	if repoStatus == "" {
		lines = append(lines, "*Repo:* `clean (no uncommitted changes)`")
	} else {
		lines = append(lines, fmt.Sprintf("*Repo (uncommitted):*\n```\n%s\n```", repoStatus))
	}

	lastUpdate := runCmd("cd /home/ivali/nixos-infrastructure && git log --oneline -1 --format='%cr %s' 2>/dev/null", 5)
	lastUpdate = strings.TrimSpace(lastUpdate)
	if lastUpdate != "" {
		lines = append(lines, fmt.Sprintf("*Last commit:* `%s`", lastUpdate))
	}

	lines = append(lines, "")
	lines = append(lines, "_Tap /update to pull and update flake inputs._")

	return c.api.SendLongMessage(msg.ChatID, strings.Join(lines, "\n"), 3500)
}
