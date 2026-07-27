package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/renderer"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type UptimeCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewUptimeCommand(api *telegram.API, svc *services.Container) *UptimeCommand {
	return &UptimeCommand{api: api, svc: svc}
}

func (c *UptimeCommand) Name() string                      { return "uptime" }
func (c *UptimeCommand) Description() string               { return "Show system uptime" }
func (c *UptimeCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *UptimeCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := strings.TrimSpace(c.svc.System.Uptime())
	if output == "" {
		return c.api.SendMarkdown(msg.ChatID, "Failed to retrieve uptime.")
	}
	return c.api.SendMarkdown(msg.ChatID, renderer.BuildCard(renderer.Card{
		Title: "System Uptime",
		Lines: []string{renderer.InlineCode(output)},
	}))
}

type MemoryCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewMemoryCommand(api *telegram.API, svc *services.Container) *MemoryCommand {
	return &MemoryCommand{api: api, svc: svc}
}

func (c *MemoryCommand) Name() string                      { return "memory" }
func (c *MemoryCommand) Description() string               { return "Show memory usage" }
func (c *MemoryCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *MemoryCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	memLine, swapLine, raw := c.svc.System.Memory()
	if raw == "" {
		return c.api.SendMarkdown(msg.ChatID, "Failed to retrieve memory info.")
	}

	var lines []string
	lines = append(lines, "*Memory Usage*")
	lines = append(lines, "")
	if memLine != "" {
		lines = append(lines, memLine)
	}
	if swapLine != "" {
		lines = append(lines, "")
		lines = append(lines, swapLine)
	}
	lines = append(lines, "")
	lines = append(lines, renderer.CodeBlock(raw))

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

type CPUCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewCPUCommand(api *telegram.API, svc *services.Container) *CPUCommand {
	return &CPUCommand{api: api, svc: svc}
}

func (c *CPUCommand) Name() string                      { return "cpu" }
func (c *CPUCommand) Description() string               { return "Show CPU load" }
func (c *CPUCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *CPUCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	loadAvg := strings.TrimSpace(c.svc.Runner.Run("cat /proc/loadavg 2>/dev/null", 5))
	if loadAvg == "" {
		return c.api.SendMarkdown(msg.ChatID, "Failed to retrieve CPU info.")
	}

	var lines []string
	lines = append(lines, "*CPU Status*")
	lines = append(lines, "")

	parts := strings.Fields(loadAvg)
	if len(parts) >= 3 {
		lines = append(lines, "*Load averages (1/5/15 min):*")
		lines = append(lines, fmt.Sprintf("  1 min:  `%s`", parts[0]))
		lines = append(lines, fmt.Sprintf("  5 min:  `%s`", parts[1]))
		lines = append(lines, fmt.Sprintf("  15 min: `%s`", parts[2]))
	}

	cores := strings.TrimSpace(c.svc.System.CPUCores())
	lines = append(lines, "")
	lines = append(lines, renderer.KeyValue("CPU cores", cores))

	model := strings.TrimSpace(c.svc.System.CPUModel())
	if model != "" {
		lines = append(lines, renderer.KeyValue("Model", model))
	}

	lines = append(lines, "")
	lines = append(lines, renderer.CodeBlock(loadAvg))

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

type UpdatesCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewUpdatesCommand(api *telegram.API, svc *services.Container) *UpdatesCommand {
	return &UpdatesCommand{api: api, svc: svc}
}

func (c *UpdatesCommand) Name() string                      { return "updates" }
func (c *UpdatesCommand) Description() string               { return "Show update status" }
func (c *UpdatesCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *UpdatesCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Update Status*")
	lines = append(lines, "")

	pkgCount := strings.TrimSpace(c.svc.Nix.SystemPackageCount())
	if pkgCount == "" {
		pkgCount = "unknown"
	}
	lines = append(lines, renderer.KeyValue("Installed system packages", pkgCount))

	gen := strings.TrimSpace(c.svc.Nix.CurrentGeneration())
	if gen != "" {
		lines = append(lines, renderer.KeyValue("Current generation", gen))
	}

	repoStatus := strings.TrimSpace(c.svc.Git.Status())
	if repoStatus == "" {
		lines = append(lines, "*Repo:* `clean (no uncommitted changes)`")
	} else {
		lines = append(lines, fmt.Sprintf("*Repo (uncommitted):*\n%s", renderer.CodeBlock(repoStatus)))
	}

	lastUpdate := strings.TrimSpace(c.svc.Git.HeadCommitRelative())
	if lastUpdate != "" {
		lines = append(lines, renderer.KeyValue("Last commit", lastUpdate))
	}

	lines = append(lines, "")
	lines = append(lines, "_Tap /update to pull and update flake inputs._")

	return c.api.SendLongMessage(msg.ChatID, strings.Join(lines, "\n"), 3500)
}
