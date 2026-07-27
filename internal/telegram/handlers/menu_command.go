package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/renderer"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type MenuInlineCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewMenuInlineCommand(api *telegram.API, svc *services.Container) *MenuInlineCommand {
	return &MenuInlineCommand{api: api, svc: svc}
}

func (c *MenuInlineCommand) Name() string                      { return "menu_inline" }
func (c *MenuInlineCommand) Description() string               { return "Show interactive menu" }
func (c *MenuInlineCommand) RequiredPermission() telegram.Role { return telegram.RoleGuest }

func (c *MenuInlineCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	if msg.IsCallback {
		return c.handleMenuCallback(msg)
	}
	return c.sendMainMenu(msg.ChatID)
}

func (c *MenuInlineCommand) HandleCallback(ctx context.Context, queryID string, chatID int64, userID int, data string, messageID int) error {
	if err := c.api.AnswerCallback(queryID, ""); err != nil {
		return err
	}
	return c.handleMenuCallback(&telegram.Message{
		ChatID:          chatID,
		UserID:          userID,
		IsCallback:      true,
		CallbackPayload: data,
		CallbackID:      queryID,
		MessageID:       messageID,
	})
}

// editOrSend edits the existing message if messageID > 0, otherwise sends a new one.
func (c *MenuInlineCommand) editOrSend(chatID int64, messageID int, text string, buttons []telegram.InlineButton) error {
	if messageID > 0 {
		return c.api.EditMessageWithKeyboard(chatID, messageID, text, buttons)
	}
	return c.api.SendInlineKeyboard(chatID, text, buttons)
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

// backButton returns an inline keyboard button that returns to the main menu.
func backButton() telegram.InlineButton {
	return telegram.InlineButton{Text: "⬅️ Back", CallbackData: "menu:main"}
}

func (c *MenuInlineCommand) handleMenuCallback(msg *telegram.Message) error {
	data := msg.CallbackPayload
	category := strings.TrimPrefix(data, "menu:")

	// "main" routes back to the main menu
	if category == "main" {
		if msg.MessageID > 0 {
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
			return c.api.EditMessageWithKeyboard(msg.ChatID, msg.MessageID,
				"*ivali — Operations Console*\n\nSelect a category:", buttons)
		}
		return c.sendMainMenu(msg.ChatID)
	}

	switch category {
	case "system":
		return c.showSystem(msg)
	case "gitops":
		return c.showGitOps(msg)
	case "security":
		return c.showSecurity(msg)
	case "tailscale":
		return c.showTailscale(msg)
	case "monitoring":
		return c.showMonitoring(msg)
	case "backup":
		return c.showBackup(msg)
	case "services":
		return c.showServices(msg)
	case "ai":
		return c.showAI(msg)
	case "repository":
		return c.showRepository(msg)
	case "firewall":
		return c.showFirewall(msg)
	case "recovery":
		return c.showRecovery(msg)
	case "help":
		return c.showHelp(msg)
	default:
		if msg.MessageID > 0 {
			return c.api.EditMessageMarkdown(msg.ChatID, msg.MessageID,
				"Unknown category: `"+category+"`")
		}
		return c.api.SendMarkdown(msg.ChatID, "Unknown category: `"+category+"`")
	}
}

func (c *MenuInlineCommand) showSystem(msg *telegram.Message) error {
	uptime := strings.TrimSpace(c.svc.System.Uptime())
	mem := strings.TrimSpace(c.svc.Runner.Run(
		"free -h | awk '/^Mem:/{printf \"%s used / %s total (%s free)\", $3, $2, $4}'", 5))
	load := strings.TrimSpace(c.svc.System.LoadAvg())
	disk := strings.TrimSpace(c.svc.System.DiskUsage())
	cores := strings.TrimSpace(c.svc.System.CPUCores())

	text := renderer.BuildCard(renderer.Card{
		Title: "System Status",
		Icon:  "🖥️",
		Lines: []string{
			renderer.KeyValue("Uptime", uptime),
			renderer.KeyValue("Memory", mem),
			renderer.KeyValue("Load avg", load),
			renderer.KeyValue("Disk /", disk),
			renderer.KeyValue("CPU cores", cores),
		},
		Footer: "Use /top for full metrics",
	})

	buttons := []telegram.InlineButton{
		{Text: "📊 Top", CallbackData: "cmd:top"},
		{Text: "🧠 Memory", CallbackData: "cmd:memory"},
		{Text: "💻 CPU", CallbackData: "cmd:cpu"},
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, text, buttons)
}

func (c *MenuInlineCommand) showGitOps(msg *telegram.Message) error {
	genCount := strings.TrimSpace(c.svc.Nix.GenerationCount())
	currentGen := strings.TrimSpace(c.svc.Nix.CurrentGeneration())
	dirty := strings.TrimSpace(c.svc.Git.DirtyCount())
	head := strings.TrimSpace(c.svc.Git.HeadCommit())
	reconciler := strings.TrimSpace(c.svc.GitOps.ReconcilerStatus())

	repoStatus := "✅ `clean`"
	if dirty != "0" && dirty != "" {
		repoStatus = fmt.Sprintf("⚠️ *Uncommitted changes:* `%s files`", dirty)
	}

	text := renderer.BuildCard(renderer.Card{
		Title: "GitOps Status",
		Icon:  "🔄",
		Lines: []string{
			renderer.KeyValue("Generations", genCount),
			renderer.KeyValue("Current", currentGen),
			"*Repo:* " + repoStatus,
			renderer.KeyValue("Latest commit", head),
			renderer.KeyValue("Reconciler", reconciler),
		},
		Footer: "Use /deploy to rebuild · /rollback to revert",
	})

	buttons := []telegram.InlineButton{
		{Text: "🚀 Deploy", CallbackData: "cmd:deploy"},
		{Text: "⏪ Rollback", CallbackData: "cmd:rollback"},
		{Text: "📋 Diff", CallbackData: "cmd:diff"},
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, text, buttons)
}

func (c *MenuInlineCommand) showSecurity(msg *telegram.Message) error {
	result := c.svc.Security.SecuritySummary()
	text := strings.Join(result.Lines, "\n")

	buttons := []telegram.InlineButton{
		{Text: "🔍 Full Scan", CallbackData: "cmd:security"},
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, text, buttons)
}

func (c *MenuInlineCommand) showTailscale(msg *telegram.Message) error {
	lines := c.svc.Tailscale.FormatStatus()
	text := strings.Join(lines, "\n")

	buttons := []telegram.InlineButton{
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, text, buttons)
}

func (c *MenuInlineCommand) showMonitoring(msg *telegram.Message) error {
	statuses := c.svc.Monitoring.ServiceStatuses()
	var lines []string
	lines = append(lines, "📊 *Monitoring Status*")
	lines = append(lines, "")

	labels := map[string]string{
		"prometheus": "📈 Prometheus",
		"grafana":    "📉 Grafana",
		"loki":       "📜 Loki",
		"alloy":      "🔗 Alloy",
		"falco":      "🔍 Falco",
	}
	for svc, label := range labels {
		status := statuses[svc]
		lines = append(lines, fmt.Sprintf("%s *%s:* `%s`", renderer.StatusIcon(status == "active"), label, status))
	}

	lines = append(lines, "")
	lines = append(lines, "_Use /metrics for Prometheus data_")

	buttons := []telegram.InlineButton{
		{Text: "📊 Metrics", CallbackData: "cmd:metrics"},
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, strings.Join(lines, "\n"), buttons)
}

func (c *MenuInlineCommand) showBackup(msg *telegram.Message) error {
	restic := strings.TrimSpace(c.svc.GitOps.ResticStatus())
	lastSnap := strings.TrimSpace(c.svc.GitOps.LastSnapshot())
	lastRun := strings.TrimSpace(c.svc.GitOps.ResticLastRun())

	var lines []string
	lines = append(lines, "💾 *Backup Status*")
	lines = append(lines, "")
	lines = append(lines, renderer.KeyValue("Restic service", restic))
	lines = append(lines, renderer.KeyValue("Latest snapshot", lastSnap))
	if lastRun != "" && lastRun != "[not set]" {
		lines = append(lines, renderer.KeyValue("Last run", lastRun))
	}

	buttons := []telegram.InlineButton{
		{Text: "💾 Backup Now", CallbackData: "cmd:backup_now"},
		{Text: "♻️ Restore", CallbackData: "cmd:restore"},
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, strings.Join(lines, "\n"), buttons)
}

func (c *MenuInlineCommand) showServices(msg *telegram.Message) error {
	svcList := []string{
		"ivali-bot", "sshd", "NetworkManager", "tailscaled",
		"prometheus", "grafana", "loki", "alloy", "falco", "fail2ban",
	}

	var lines []string
	lines = append(lines, "⚙️ *Service Status*")
	lines = append(lines, "")

	for _, svc := range svcList {
		status := strings.TrimSpace(c.svc.System.ServiceStatus(svc))
		lines = append(lines, renderer.ServiceStatusLine(svc, status))
	}

	failed := strings.TrimSpace(c.svc.System.FailedUnits())
	lines = append(lines, "")
	if failed == "0" || failed == "" {
		lines = append(lines, "✅ *No failed units*")
	} else {
		lines = append(lines, fmt.Sprintf("❌ *Failed units: %s* — use /log for details", failed))
	}

	buttons := []telegram.InlineButton{
		{Text: "📋 Journal", CallbackData: "cmd:journal"},
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, strings.Join(lines, "\n"), buttons)
}

func (c *MenuInlineCommand) showAI(msg *telegram.Message) error {
	status := c.svc.AI.Status()

	text := renderer.BuildCard(renderer.Card{
		Title: "AI Systems Status",
		Icon:  "🤖",
		Lines: []string{
			renderer.KeyValue("💻 OpenCode", status.OpenCode),
			renderer.KeyValue("🦾 OpenHands", status.OpenHands),
			renderer.KeyValue("📚 Knowledge base", status.KnowledgeBase),
		},
		Footer: "All tasks route to OpenCode",
	})

	buttons := []telegram.InlineButton{
		{Text: "💻 OpenCode", CallbackData: "cmd:opencode"},
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, text, buttons)
}

func (c *MenuInlineCommand) showRepository(msg *telegram.Message) error {
	output := c.svc.Platform.Status()
	text := "*📁 Repository Status*\n\n" + renderer.CodeBlock(output)

	buttons := []telegram.InlineButton{
		{Text: "🔍 Search", CallbackData: "cmd:search"},
		{Text: "📊 Graph", CallbackData: "cmd:graph"},
		{Text: "💡 Suggest", CallbackData: "cmd:suggest"},
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, text, buttons)
}

func (c *MenuInlineCommand) showFirewall(msg *telegram.Message) error {
	lines := c.svc.Firewall.FormatStatus()
	text := strings.Join(lines, "\n")

	buttons := []telegram.InlineButton{
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, text, buttons)
}

func (c *MenuInlineCommand) showRecovery(msg *telegram.Message) error {
	gens := strings.TrimSpace(c.svc.Nix.GenerationCount())
	health := strings.TrimSpace(c.svc.Runner.Run(
		"systemctl is-active deployment-health 2>/dev/null || echo unknown", 5))
	lastDeploy := strings.TrimSpace(c.svc.Runner.Run(
		"journalctl -u nixos-rebuild --no-pager -n 1 --output=short-iso 2>/dev/null | head -1 || echo unknown", 5))

	text := renderer.BuildCard(renderer.Card{
		Title: "Recovery Status",
		Icon:  "♻️",
		Lines: []string{
			renderer.KeyValue("Available generations", gens),
			renderer.KeyValue("Health monitor", health),
			renderer.KeyValue("Last rebuild log", lastDeploy),
		},
		Footer: "Use /rollback to revert · /generations to list",
	})

	buttons := []telegram.InlineButton{
		{Text: "⏪ Rollback", CallbackData: "cmd:rollback"},
		{Text: "📋 Generations", CallbackData: "cmd:generations"},
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, text, buttons)
}

func (c *MenuInlineCommand) showHelp(msg *telegram.Message) error {
	lines := []string{
		"❓ *Available Commands*",
		"",
		"*📊 Status:* /status /health /top /memory /cpu /disk /uptime /updates",
		"*🔄 Operations:* /deploy /rollback /reboot /shutdown /update /gc",
		"*🛠 GitOps:* /diff /reconcile /verify /backup\\_now /restore",
		"*🌐 Network:* /tailscale /firewall /network",
		"*🖥 Desktop:* /open /apps /screenshot /clipboard /volume /brightness /mute /unmute /windows /workspace /firefox /desktop\\_power /monitoron",
		"*💻 Dev:* /git /github /gitlab /nix /run /scan /doctor /store /pkg /speedtest",
		"*🤖 AI:* /ai /opencode",
		"*📁 Repo:* /repo /search /graph /suggest /inventory /events /plugins /state",
		"*📋 Logs:* /log /journal /metrics /processes /security",
		"*ℹ️ Info:* /help /menu /menu\\_inline /start /generations /auth /users /notify",
		"",
		"_Tap /menu for the main keyboard_",
	}
	text := strings.Join(lines, "\n")

	buttons := []telegram.InlineButton{
		backButton(),
	}

	return c.editOrSend(msg.ChatID, msg.MessageID, text, buttons)
}
