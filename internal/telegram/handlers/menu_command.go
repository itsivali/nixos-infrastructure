package handlers

import (
	"context"
	"fmt"
	"strings"

	"golang.org/x/text/cases"
	"golang.org/x/text/language"

	"github.com/itsivali/nixos-infrastructure/internal/security"
	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// MenuInlineCommand displays an inline-keyboard menu with 8 icon categories.
// Each button carries a "menu:<category>" callback payload; pressing one
// sends the relevant status report.
type MenuInlineCommand struct {
	api *telegram.API
}

func NewMenuInlineCommand(config *telegram.Config) *MenuInlineCommand {
	return &MenuInlineCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *MenuInlineCommand) Name() string                      { return "menu_inline" }
func (c *MenuInlineCommand) Description() string               { return "Show interactive menu" }
func (c *MenuInlineCommand) RequiredPermission() telegram.Role { return telegram.RoleGuest }

func (c *MenuInlineCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback {
		return c.handleCallback(ctx, msg)
	}

	buttons := []telegram.InlineButton{
		{Text: "\U0001f5a5\ufe0f System", CallbackData: "menu:system"},
		{Text: "\U0001f504 GitOps", CallbackData: "menu:gitops"},
		{Text: "\U0001f6e1\ufe0f Security", CallbackData: "menu:security"},
		{Text: "\U0001f310 Tailscale", CallbackData: "menu:tailscale"},
		{Text: "\U0001f4ca Monitoring", CallbackData: "menu:monitoring"},
		{Text: "\U0001f4be Backup", CallbackData: "menu:backup"},
		{Text: "\u2699\ufe0f Services", CallbackData: "menu:services"},
		{Text: "\u2753 Help", CallbackData: "menu:help"},
	}

	return c.api.SendInlineKeyboard(msg.ChatID, "*ivali bot \u2014 Main Menu*\n\nTap a category to view status.", buttons)
}

func (c *MenuInlineCommand) handleCallback(_ context.Context, msg *telegram.Message) error {
	data := msg.CallbackData()

	if err := c.api.AnswerCallback(msg.CallbackID, ""); err != nil {
		return err
	}

	category := strings.TrimPrefix(data, "menu:")
	switch category {
	case "system":
		return c.showSystem(msg.ChatID)
	case "gitops":
		return c.showGitOps(msg.ChatID)
	case "security":
		return c.showSecurity(msg.ChatID)
	case "tailscale":
		return c.showTailscale(msg.ChatID)
	case "monitoring":
		return c.showMonitoring(msg.ChatID)
	case "backup":
		return c.showBackup(msg.ChatID)
	case "services":
		return c.showServices(msg.ChatID)
	case "help":
		return c.showHelp(msg.ChatID)
	default:
		return c.api.SendMarkdown(msg.ChatID, "Unknown category: `"+category+"`")
	}
}

func (c *MenuInlineCommand) showSystem(chatID int64) error {
	var lines []string
	lines = append(lines, "*System Status*")
	lines = append(lines, "")

	uptime := runCmd("uptime -p 2>/dev/null || uptime", 5)
	lines = append(lines, fmt.Sprintf("*Uptime:* `%s`", strings.TrimSpace(uptime)))

	mem := runCmd("free -h | awk '/^Mem:/{printf \"%s used / %s total (%s free)\", $3, $2, $4}", 5)
	lines = append(lines, fmt.Sprintf("*Memory:* `%s`", strings.TrimSpace(mem)))

	load := runCmd("cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}'", 5)
	lines = append(lines, fmt.Sprintf("*Load avg:* `%s`", strings.TrimSpace(load)))

	disk := runCmd("df -h / | awk 'NR==2{printf \"%s used / %s (%s)\", $3, $2, $5}", 5)
	lines = append(lines, fmt.Sprintf("*Disk /:* `%s`", strings.TrimSpace(disk)))

	lines = append(lines, "")
	lines = append(lines, "_Tap /status for full details_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showGitOps(chatID int64) error {
	var lines []string
	lines = append(lines, "*GitOps Status*")
	lines = append(lines, "")

	gen := runCmd("nixos-rebuild --version 2>/dev/null || echo 'unknown'", 5)
	lines = append(lines, fmt.Sprintf("*Rebuild tool:* `%s`", strings.TrimSpace(gen)))

	genCount := runCmd("nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | wc -l", 10)
	lines = append(lines, fmt.Sprintf("*Generations:* `%s`", strings.TrimSpace(genCount)))

	dirty := runCmd("cd /home/ivali/nixos-infrastructure && git status --porcelain 2>/dev/null | wc -l", 5)
	lines = append(lines, fmt.Sprintf("*Uncommitted changes:* `%s`", strings.TrimSpace(dirty)))

	head := runCmd("cd /home/ivali/nixos-infrastructure && git log --oneline -1 2>/dev/null", 5)
	lines = append(lines, fmt.Sprintf("*Latest commit:* `%s`", strings.TrimSpace(head)))

	lines = append(lines, "")
	lines = append(lines, "_Tap /deploy to rebuild, /rollback to revert_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showSecurity(chatID int64) error {
	result, err := security.RunFullScan()
	if err != nil {
		return c.api.SendMarkdown(chatID, fmt.Sprintf("*Security scan failed:* `%s`", err))
	}

	var lines []string
	lines = append(lines, "*Security Status*")
	lines = append(lines, "")

	for _, cat := range result.Categories {
		icon := "✅"
		if !cat.Pass {
			icon = "❌"
		}
		lines = append(lines, fmt.Sprintf("*%s %s*", icon, cases.Title(language.Und).String(cat.Name)))
		for _, check := range cat.Checks {
			checkIcon := "  ✅"
			if !check.Pass {
				if check.Severity == "critical" || check.Severity == "high" {
					checkIcon = "  ❌"
				} else {
					checkIcon = "  ⚠️"
				}
			}
			lines = append(lines, fmt.Sprintf("%s %s", checkIcon, check.Name))
		}
		lines = append(lines, "")
	}

	lines = append(lines, "_Tap /security for full details_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showTailscale(chatID int64) error {
	output := runCmd("tailscale status 2>&1 || echo 'tailscale not available'", 10)
	return c.api.SendLongMessage(chatID, fmt.Sprintf("*Tailscale Status*\n```%s\n```", output), 3500)
}

func (c *MenuInlineCommand) showMonitoring(chatID int64) error {
	var lines []string
	lines = append(lines, "*Monitoring Status*")
	lines = append(lines, "")

	prom := runCmd("systemctl is-active prometheus >/dev/null 2>&1 && echo active || echo inactive", 5)
	lines = append(lines, fmt.Sprintf("*Prometheus:* `%s`", strings.TrimSpace(prom)))

	grafana := runCmd("systemctl is-active grafana-agent >/dev/null 2>&1 && echo active || echo inactive", 5)
	lines = append(lines, fmt.Sprintf("*Grafana Agent:* `%s`", strings.TrimSpace(grafana)))

	loki := runCmd("systemctl is-active loki >/dev/null 2>&1 && echo active || echo inactive", 5)
	lines = append(lines, fmt.Sprintf("*Loki:* `%s`", strings.TrimSpace(loki)))

	falco := runCmd("systemctl is-active falco >/dev/null 2>&1 && echo active || echo inactive", 5)
	lines = append(lines, fmt.Sprintf("*Falco:* `%s`", strings.TrimSpace(falco)))

	lines = append(lines, "")
	lines = append(lines, "_Tap /metrics for Prometheus query_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showBackup(chatID int64) error {
	var lines []string
	lines = append(lines, "*Backup Status*")
	lines = append(lines, "")

	restic := runCmd("systemctl is-active restic-backup >/dev/null 2>&1 && echo active || echo inactive", 5)
	lines = append(lines, fmt.Sprintf("*Restic backup service:* `%s`", strings.TrimSpace(restic)))

	lastSnap := runCmd("restic snapshots --latest 1 2>/dev/null | tail -1 || echo 'no snapshots'", 10)
	lines = append(lines, fmt.Sprintf("*Latest snapshot:* `%s`", strings.TrimSpace(lastSnap)))

	lines = append(lines, "")
	lines = append(lines, "_Tap /backup_now to trigger, /restore to list snapshots_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showServices(chatID int64) error {
	var lines []string
	lines = append(lines, "*Service Status*")
	lines = append(lines, "")

	services := []string{"ivali-bot", "sshd", "NetworkManager", "tailscaled"}
	for _, svc := range services {
		status := runCmd(fmt.Sprintf("systemctl is-active %s 2>/dev/null || echo unknown", svc), 5)
		lines = append(lines, fmt.Sprintf("*%s:* `%s`", svc, strings.TrimSpace(status)))
	}

	lines = append(lines, "")
	lines = append(lines, "_Tap /log for recent journal entries_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showHelp(chatID int64) error {
	var lines []string
	lines = append(lines, "*Available Commands*")
	lines = append(lines, "")
	lines = append(lines, "*System:* /status /health /disk /processes /uptime /memory /cpu")
	lines = append(lines, "*Operations:* /deploy /rollback /reboot /shutdown /update")
	lines = append(lines, "*GitOps:* /diff /reconcile /verify /backup_now /restore")
	lines = append(lines, "*Network:* /tailscale /firewall")
	lines = append(lines, "*Desktop:* /open /apps /screenshot /volume /brightness")
	lines = append(lines, "*Dev:* /git /nix /run /scan /doctor")
	lines = append(lines, "*Info:* /help /menu /menu_inline /top /generations")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}
