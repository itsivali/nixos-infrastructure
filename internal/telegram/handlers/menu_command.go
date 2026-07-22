package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/willisivali/nixos-infrastructure/internal/telegram"
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
		{Text: "\U0001f916 Jules", CallbackData: "menu:jules"},
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
	case "jules":
		return c.showJules(msg.ChatID)
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
	var lines []string
	lines = append(lines, "*Security Status*")
	lines = append(lines, "")

	fw := runCmd("nft list ruleset >/dev/null 2>&1 && echo enabled || echo disabled", 5)
	lines = append(lines, fmt.Sprintf("*Firewall:* `%s`", strings.TrimSpace(fw)))

	aa := runCmd("aa-status --enabled >/dev/null 2>&1 && echo enforced || echo inactive", 5)
	lines = append(lines, fmt.Sprintf("*AppArmor:* `%s`", strings.TrimSpace(aa)))

	ssh := runCmd("systemctl is-active sshd >/dev/null 2>&1 && echo active || echo inactive", 5)
	lines = append(lines, fmt.Sprintf("*SSH:* `%s`", strings.TrimSpace(ssh)))

	f2b := runCmd("systemctl is-active fail2ban >/dev/null 2>&1 && echo active || echo inactive", 5)
	lines = append(lines, fmt.Sprintf("*Fail2ban:* `%s`", strings.TrimSpace(f2b)))

	lines = append(lines, "")
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

func (c *MenuInlineCommand) showJules(chatID int64) error {
	var lines []string
	lines = append(lines, "*Jules AI Agent*")
	lines = append(lines, "")

	binCheck := runCmd("which jules 2>/dev/null && echo found || echo not_found", 5)
	binCheck = strings.TrimSpace(binCheck)
	if binCheck == "found" {
		lines = append(lines, "*CLI:* `installed`")
	} else {
		lines = append(lines, "*CLI:* `not installed`")
		lines = append(lines, "")
		lines = append(lines, "_Jules is not installed on this host._")
		return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
	}

	apiKeyCheck := runCmd("test -f /run/secrets/jules-api-key && echo present || echo missing", 5)
	apiKeyCheck = strings.TrimSpace(apiKeyCheck)
	if apiKeyCheck == "present" {
		lines = append(lines, "*API key:* `configured`")
	} else {
		lines = append(lines, "*API key:* `not found`")
	}

	lines = append(lines, "")
	lines = append(lines, "*Commands:*")
	lines = append(lines, "  /jules_status — Connection status")
	lines = append(lines, "  /jules_tasks — List tasks")
	lines = append(lines, "  /jules_new — Create a task")
	lines = append(lines, "  /jules_history — Past tasks")

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
	lines = append(lines, "*AI Agent:* /jules_status /jules_tasks /jules_new /jules_history")
	lines = append(lines, "*Info:* /help /menu /menu_inline /top /generations")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}
