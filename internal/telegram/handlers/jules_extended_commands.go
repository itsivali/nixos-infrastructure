package handlers

import (
	"context"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// JulesLogsCommand shows Jules task logs.
type JulesLogsCommand struct {
	api *telegram.API
}

func NewJulesLogsCommand(config *telegram.Config) *JulesLogsCommand {
	return &JulesLogsCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *JulesLogsCommand) Name() string                      { return "jules_logs" }
func (c *JulesLogsCommand) Description() string               { return "Show Jules task logs" }
func (c *JulesLogsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *JulesLogsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Jules Task Logs*")
	lines = append(lines, "")

	// Check if jules CLI is available
	check := runCmd("which jules 2>/dev/null && echo available || echo missing", 5)
	if strings.TrimSpace(check) == "missing" {
		lines = append(lines, "`Jules CLI not installed.`")
		lines = append(lines, "_Install via: nix develop (with jules in devShell)_")
		return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
	}

	// Try to get recent task history
	output := runCmd("jules history 2>&1 | head -20", 15)
	output = strings.TrimSpace(output)
	if output == "" {
		lines = append(lines, "`No recent Jules tasks found.`")
	} else {
		lines = append(lines, "```")
		lines = append(lines, output)
		lines = append(lines, "```")
	}

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

// JulesConfigCommand shows or sets Jules configuration.
type JulesConfigCommand struct {
	api *telegram.API
}

func NewJulesConfigCommand(config *telegram.Config) *JulesConfigCommand {
	return &JulesConfigCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *JulesConfigCommand) Name() string                      { return "jules_config" }
func (c *JulesConfigCommand) Description() string               { return "Show Jules configuration" }
func (c *JulesConfigCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *JulesConfigCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Jules Configuration*")
	lines = append(lines, "")

	// Check Jules CLI
	check := runCmd("which jules 2>/dev/null && echo available || echo missing", 5)
	if strings.TrimSpace(check) == "missing" {
		lines = append(lines, "`Jules CLI not installed.`")
		return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
	}

	// Check API key
	apiKey := runCmd("test -f ~/.jules/config.yaml && grep -q 'api_key' ~/.jules/config.yaml && echo configured || echo missing", 5)
	if strings.TrimSpace(apiKey) == "configured" {
		lines = append(lines, "*API Key:* `configured`")
	} else {
		lines = append(lines, "*API Key:* `not configured`")
		lines = append(lines, "_Set via: jules login_")
	}

	// Check auth status
	auth := runCmd("jules status 2>&1 | head -5", 10)
	auth = strings.TrimSpace(auth)
	if auth != "" {
		lines = append(lines, "")
		lines = append(lines, "*Status:*")
		lines = append(lines, "```")
		lines = append(lines, auth)
		lines = append(lines, "```")
	}

	lines = append(lines, "")
	lines = append(lines, "_Use /jules_new <description> to create tasks_")

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}
