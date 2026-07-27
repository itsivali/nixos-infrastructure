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

// MenuInlineCommand displays an inline-keyboard menu with icon categories.
// It implements both Command (for /menu_inline) and CallbackHandler (for
// menu: prefix callbacks from the inline keyboard buttons).
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
		return c.handleMenuCallback(msg.ChatID, msg.CallbackID, msg.CallbackData())
	}
	return c.sendMainMenu(msg.ChatID)
}

// HandleCallback implements telegram.CallbackHandler so the bot can route
// "menu:<category>" payloads to this handler.
func (c *MenuInlineCommand) HandleCallback(ctx context.Context, queryID string, chatID int64, userID int, data string) error {
	if err := c.api.AnswerCallback(queryID, ""); err != nil {
		return err
	}
	return c.handleMenuCallback(chatID, queryID, data)
}

func (c *MenuInlineCommand) sendMainMenu(chatID int64) error {
	buttons := []telegram.InlineButton{
		{Text: "🖥️ System", CallbackData: "menu:system"},
		{Text: "🔄 GitOps", CallbackData: "menu:gitops"},
		{Text: "🛡️ Security", CallbackData: "menu:security"},
		{Text: "🌐 Tailscale", CallbackData: "menu:tailscale"},
		{Text: "📊 Monitoring", CallbackData: "menu:monitoring"},
		{Text: "💾 Backup", CallbackData: "menu:backup"},
		{Text: "⚙️ Services", CallbackData: "menu:services"},
		{Text: "🤖 AI", CallbackData: "menu:ai"},
		{Text: "📁 Repository", CallbackData: "menu:repository"},
		{Text: "🔥 Firewall", CallbackData: "menu:firewall"},
		{Text: "♻️ Recovery", CallbackData: "menu:recovery"},
		{Text: "❓ Help", CallbackData: "menu:help"},
	}

	return c.api.SendInlineKeyboard(chatID,
		"*ivali — Operations Console*\n\nSelect a category:", buttons)
}

func (c *MenuInlineCommand) handleMenuCallback(chatID int64, queryID, data string) error {
	category := strings.TrimPrefix(data, "menu:")
	switch category {
	case "system":
		return c.showSystem(chatID)
	case "gitops":
		return c.showGitOps(chatID)
	case "security":
		return c.showSecurity(chatID)
	case "tailscale":
		return c.showTailscale(chatID)
	case "monitoring":
		return c.showMonitoring(chatID)
	case "backup":
		return c.showBackup(chatID)
	case "services":
		return c.showServices(chatID)
	case "ai":
		return c.showAI(chatID)
	case "repository":
		return c.showRepository(chatID)
	case "firewall":
		return c.showFirewall(chatID)
	case "recovery":
		return c.showRecovery(chatID)
	case "help":
		return c.showHelp(chatID)
	default:
		return c.api.SendMarkdown(chatID, "Unknown category: `"+category+"`")
	}
}

func (c *MenuInlineCommand) showSystem(chatID int64) error {
	var lines []string
	lines = append(lines, "🖥️ *System Status*")
	lines = append(lines, "")

	uptime := runCmd("uptime -p 2>/dev/null || uptime", 5)
	lines = append(lines, fmt.Sprintf("⏱ *Uptime:* `%s`", strings.TrimSpace(uptime)))

	mem := runCmd("free -h | awk '/^Mem:/{printf \"%s used / %s total (%s free)\", $3, $2, $4}'", 5)
	lines = append(lines, fmt.Sprintf("🧠 *Memory:* `%s`", strings.TrimSpace(mem)))

	load := runCmd("cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}'", 5)
	lines = append(lines, fmt.Sprintf("⚡ *Load avg:* `%s`", strings.TrimSpace(load)))

	disk := runCmd("df -h / | awk 'NR==2{printf \"%s used / %s (%s)\", $3, $2, $5}'", 5)
	lines = append(lines, fmt.Sprintf("💽 *Disk /:* `%s`", strings.TrimSpace(disk)))

	cores := runCmd("nproc 2>/dev/null || echo unknown", 5)
	lines = append(lines, fmt.Sprintf("🔧 *CPU cores:* `%s`", strings.TrimSpace(cores)))

	lines = append(lines, "")
	lines = append(lines, "_Use /top for full metrics_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showGitOps(chatID int64) error {
	var lines []string
	lines = append(lines, "🔄 *GitOps Status*")
	lines = append(lines, "")

	genCount := runCmd("nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | wc -l", 10)
	lines = append(lines, fmt.Sprintf("🗂 *Generations:* `%s`", strings.TrimSpace(genCount)))

	currentGen := runCmd("readlink /run/current-system 2>/dev/null | grep -oP 'nixos-\\d+' || echo unknown", 5)
	lines = append(lines, fmt.Sprintf("📌 *Current:* `%s`", strings.TrimSpace(currentGen)))

	dirty := runCmd("cd /home/ivali/nixos-infrastructure && git status --porcelain 2>/dev/null | wc -l", 5)
	dirtyStr := strings.TrimSpace(dirty)
	if dirtyStr == "0" || dirtyStr == "" {
		lines = append(lines, "✅ *Repo:* `clean`")
	} else {
		lines = append(lines, fmt.Sprintf("⚠️ *Uncommitted changes:* `%s files`", dirtyStr))
	}

	head := runCmd("cd /home/ivali/nixos-infrastructure && git log --oneline -1 2>/dev/null", 5)
	lines = append(lines, fmt.Sprintf("📝 *Latest commit:* `%s`", strings.TrimSpace(head)))

	reconciler := runCmd("systemctl is-active gitops-reconciler 2>/dev/null || echo unknown", 5)
	lines = append(lines, fmt.Sprintf("🤖 *Reconciler:* `%s`", strings.TrimSpace(reconciler)))

	lines = append(lines, "")
	lines = append(lines, "_Use /deploy to rebuild · /rollback to revert_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showSecurity(chatID int64) error {
	result, err := security.RunFullScan()
	if err != nil {
		return c.api.SendMarkdown(chatID, fmt.Sprintf("*Security scan failed:* `%s`", err))
	}

	var lines []string
	lines = append(lines, "🛡️ *Security Status*")
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

	lines = append(lines, fmt.Sprintf("_Score: %s_", security.ScoreFromResult(result)))
	lines = append(lines, "_Use /security for full details_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showTailscale(chatID int64) error {
	output := runCmd("tailscale status 2>&1 || echo 'tailscale not available'", 10)
	return c.api.SendLongMessage(chatID, fmt.Sprintf("🌐 *Tailscale Status*\n```%s\n```", output), 3500)
}

func (c *MenuInlineCommand) showMonitoring(chatID int64) error {
	var lines []string
	lines = append(lines, "📊 *Monitoring Status*")
	lines = append(lines, "")

	services := map[string]string{
		"prometheus": "📈 Prometheus",
		"grafana":    "📉 Grafana",
		"loki":       "📜 Loki",
		"alloy":      "🔗 Alloy",
		"falco":      "🔍 Falco",
	}
	for svc, label := range services {
		status := runCmd(fmt.Sprintf("systemctl is-active %s 2>/dev/null || echo inactive", svc), 5)
		status = strings.TrimSpace(status)
		icon := "✅"
		if status != "active" {
			icon = "❌"
		}
		lines = append(lines, fmt.Sprintf("%s *%s:* `%s`", icon, label, status))
	}

	lines = append(lines, "")
	lines = append(lines, "_Use /metrics for Prometheus data_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showBackup(chatID int64) error {
	var lines []string
	lines = append(lines, "💾 *Backup Status*")
	lines = append(lines, "")

	restic := runCmd("systemctl is-active restic-backup 2>/dev/null || echo inactive", 5)
	lines = append(lines, fmt.Sprintf("*Restic service:* `%s`", strings.TrimSpace(restic)))

	lastSnap := runCmd("restic snapshots --latest 1 --no-lock 2>/dev/null | tail -2 | head -1 || echo 'no snapshots'", 15)
	lines = append(lines, fmt.Sprintf("*Latest snapshot:* `%s`", strings.TrimSpace(lastSnap)))

	lastRun := runCmd("systemctl show restic-backup --property=ExecMainStartTimestamp 2>/dev/null | cut -d= -f2", 5)
	if lastRun != "" && lastRun != "[not set]" {
		lines = append(lines, fmt.Sprintf("*Last run:* `%s`", strings.TrimSpace(lastRun)))
	}

	lines = append(lines, "")
	lines = append(lines, "_Use /backup\\_now to trigger · /restore to list_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showServices(chatID int64) error {
	var lines []string
	lines = append(lines, "⚙️ *Service Status*")
	lines = append(lines, "")

	services := []string{
		"ivali-bot", "sshd", "NetworkManager", "tailscaled",
		"prometheus", "grafana", "loki", "alloy", "falco", "fail2ban",
	}
	for _, svc := range services {
		status := runCmd(fmt.Sprintf("systemctl is-active %s 2>/dev/null || echo unknown", svc), 5)
		status = strings.TrimSpace(status)
		icon := "✅"
		if status != "active" {
			icon = "❌"
		}
		lines = append(lines, fmt.Sprintf("%s `%-20s` %s", icon, svc, status))
	}

	// Failed units
	failed := runCmd("systemctl list-units --state=failed --no-legend 2>/dev/null | wc -l", 5)
	failed = strings.TrimSpace(failed)
	lines = append(lines, "")
	if failed == "0" || failed == "" {
		lines = append(lines, "✅ *No failed units*")
	} else {
		lines = append(lines, fmt.Sprintf("❌ *Failed units: %s* — use /log for details", failed))
	}

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showAI(chatID int64) error {
	var lines []string
	lines = append(lines, "🤖 *AI Systems Status*")
	lines = append(lines, "")

	// OpenCode
	opencode := runCmd("test -d /home/ivali/nixos-infrastructure/.opencode && echo configured || echo not configured", 5)
	lines = append(lines, fmt.Sprintf("💻 *OpenCode:* `%s`", strings.TrimSpace(opencode)))

	// OpenHands
	oh := runCmd("openhands --version 2>/dev/null | head -1 || docker ps --filter name=openhands --format '{{.Status}}' 2>/dev/null | head -1 || echo not running", 8)
	ohStr := strings.TrimSpace(oh)
	if ohStr == "" {
		ohStr = "not running"
	}
	lines = append(lines, fmt.Sprintf("🦾 *OpenHands:* `%s`", ohStr))

	// Knowledge base
	kb := runCmd("test -f /home/ivali/nixos-infrastructure/opencode/README.md && echo available || echo not found", 5)
	lines = append(lines, fmt.Sprintf("📚 *Knowledge base:* `%s`", strings.TrimSpace(kb)))

	lines = append(lines, "")
	lines = append(lines, "_Use /ai for full AI status · /opencode to check OpenCode_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showRepository(chatID int64) error {
	output := runCmd("ivali status 2>&1 | head -30 || echo 'ivali not available'", 20)
	return c.api.SendLongMessage(chatID, "📁 *Repository Status*\n\n```"+output+"```", 3500)
}

func (c *MenuInlineCommand) showFirewall(chatID int64) error {
	output := runCmd("nft list ruleset 2>/dev/null | head -40 || iptables -L -n 2>/dev/null | head -30 || echo 'firewall info not available'", 10)
	return c.api.SendLongMessage(chatID, "🔥 *Firewall Rules*\n\n```"+output+"```", 3500)
}

func (c *MenuInlineCommand) showRecovery(chatID int64) error {
	var lines []string
	lines = append(lines, "♻️ *Recovery Status*")
	lines = append(lines, "")

	// Generation count
	gens := runCmd("nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | wc -l", 10)
	lines = append(lines, fmt.Sprintf("🗂 *Available generations:* `%s`", strings.TrimSpace(gens)))

	// Health check service
	health := runCmd("systemctl is-active deployment-health 2>/dev/null || echo unknown", 5)
	lines = append(lines, fmt.Sprintf("❤️ *Health monitor:* `%s`", strings.TrimSpace(health)))

	// Last successful deploy
	lastDeploy := runCmd("journalctl -u nixos-rebuild --no-pager -n 1 --output=short-iso 2>/dev/null | head -1 || echo unknown", 5)
	lines = append(lines, fmt.Sprintf("🚀 *Last rebuild log:* `%s`", strings.TrimSpace(lastDeploy)))

	lines = append(lines, "")
	lines = append(lines, "_Use /rollback to revert · /generations to list_")

	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}

func (c *MenuInlineCommand) showHelp(chatID int64) error {
	lines := []string{
		"❓ *Available Commands*",
		"",
		"*📊 Status:* /status /health /top /memory /cpu /disk",
		"*🔄 Operations:* /deploy /rollback /reboot /shutdown /update /gc",
		"*🛠 GitOps:* /diff /reconcile /verify /backup\\_now /restore",
		"*🌐 Network:* /tailscale /firewall /network",
		"*🖥 Desktop:* /open /apps /screenshot /clipboard /volume /brightness",
		"*💻 Dev:* /git /nix /run /scan /doctor /journal",
		"*🤖 AI:* /ai /opencode",
		"*📁 Repo:* /repo /search /graph /suggest /inventory",
		"*ℹ️ Info:* /help /menu /menu\\_inline /uptime /generations /updates",
		"",
		"_Tap /menu for the main keyboard_",
	}
	return c.api.SendMarkdown(chatID, strings.Join(lines, "\n"))
}
