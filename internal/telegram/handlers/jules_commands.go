package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// JulesStatusCommand shows Jules connection and auth status.
type JulesStatusCommand struct {
	api *telegram.API
}

func NewJulesStatusCommand(config *telegram.Config) *JulesStatusCommand {
	return &JulesStatusCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *JulesStatusCommand) Name() string                      { return "jules_status" }
func (c *JulesStatusCommand) Description() string               { return "Show Jules connection status" }
func (c *JulesStatusCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *JulesStatusCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Jules Status*")
	lines = append(lines, "")

	// Check if jules binary is available
	binCheck := runCmd("which jules 2>/dev/null && echo found || echo not_found", 5)
	binCheck = strings.TrimSpace(binCheck)
	if binCheck == "found" {
		lines = append(lines, "*CLI:* `installed`")
	} else {
		lines = append(lines, "*CLI:* `not installed`")
		return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
	}

	// Check API key
	apiKeyCheck := runCmd("test -f /run/secrets/jules-api-key && echo present || echo missing", 5)
	apiKeyCheck = strings.TrimSpace(apiKeyCheck)
	if apiKeyCheck == "present" {
		lines = append(lines, "*API key:* `configured`")
	} else {
		lines = append(lines, "*API key:* `not found`")
		lines = append(lines, "")
		lines = append(lines, "_Run ivali jules login on the host to authenticate._")
		return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
	}

	// Check authentication status
	remoteList := runCmd("jules remote list 2>&1 || echo 'not authenticated'", 10)
	remoteList = strings.TrimSpace(remoteList)
	if remoteList != "" && !strings.Contains(remoteList, "not authenticated") && !strings.Contains(remoteList, "Error") {
		lines = append(lines, "*Auth:* `authenticated`")
		lines = append(lines, "")
		lines = append(lines, fmt.Sprintf("```%s```", remoteList))
	} else {
		lines = append(lines, "*Auth:* `not authenticated`")
	}

	return c.api.SendLongMessage(msg.ChatID, strings.Join(lines, "\n"), 3500)
}

// JulesTasksCommand lists all Jules tasks.
type JulesTasksCommand struct {
	api *telegram.API
}

func NewJulesTasksCommand(config *telegram.Config) *JulesTasksCommand {
	return &JulesTasksCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *JulesTasksCommand) Name() string                      { return "jules_tasks" }
func (c *JulesTasksCommand) Description() string               { return "List Jules tasks" }
func (c *JulesTasksCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *JulesTasksCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "Fetching Jules tasks...")
	output := runCmd("jules tasks 2>&1 || echo 'jules not available'", 30)
	output = strings.TrimSpace(output)
	if output == "" {
		output = "(no tasks found)"
	}
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("*Jules Tasks*\n```%s\n```", output), 3500)
}

// JulesNewCommand creates a new Jules task.
type JulesNewCommand struct {
	api *telegram.API
}

func NewJulesNewCommand(config *telegram.Config) *JulesNewCommand {
	return &JulesNewCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *JulesNewCommand) Name() string                      { return "jules_new" }
func (c *JulesNewCommand) Description() string               { return "Create a new Jules task" }
func (c *JulesNewCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *JulesNewCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.Fields(msg.Args)
	if len(args) == 0 {
		return c.api.SendMarkdown(msg.ChatID, "*Usage:* `/jules_new <task description>`\n\nExample: `/jules_new Fix the NixOS firewall configuration`")
	}

	description := strings.Join(args, " ")
	_ = c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("*Creating Jules task:*\n`%s`", description))

	output := runCmdArgs(60, "jules", "new", "--description", description)
	output = strings.TrimSpace(output)
	if output == "" {
		output = "(no output)"
	}
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("*Jules Task Created*\n```%s\n```", output), 3500)
}

// JulesCancelCommand cancels a running Jules task.
type JulesCancelCommand struct {
	api *telegram.API
}

func NewJulesCancelCommand(config *telegram.Config) *JulesCancelCommand {
	return &JulesCancelCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *JulesCancelCommand) Name() string                      { return "jules_cancel" }
func (c *JulesCancelCommand) Description() string               { return "Cancel a Jules task" }
func (c *JulesCancelCommand) RequiredPermission() telegram.Role { return telegram.RoleAdmin }

func (c *JulesCancelCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.Fields(msg.Args)
	if len(args) == 0 {
		return c.api.SendMarkdown(msg.ChatID, "*Usage:* `/jules_cancel <task-id>`")
	}

	if msg.IsCallback && msg.CallbackData() == "confirm:jules_cancel" {
		taskID := args[0]
		output := runCmd(fmt.Sprintf("jules cancel %s 2>&1", taskID), 30)
		return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("*Task Cancelled*\n```%s\n```", output), 3500)
	}

	return sendConfirm(c.api, msg.ChatID, "jules_cancel",
		fmt.Sprintf("*Cancel Jules task %s?*", args[0]))
}

// JulesHistoryCommand shows completed Jules tasks.
type JulesHistoryCommand struct {
	api *telegram.API
}

func NewJulesHistoryCommand(config *telegram.Config) *JulesHistoryCommand {
	return &JulesHistoryCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *JulesHistoryCommand) Name() string                      { return "jules_history" }
func (c *JulesHistoryCommand) Description() string               { return "Show Jules task history" }
func (c *JulesHistoryCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *JulesHistoryCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("jules history 2>&1 || echo 'jules not available'", 30)
	output = strings.TrimSpace(output)
	if output == "" {
		output = "(no history)"
	}
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("*Jules History*\n```%s\n```", output), 3500)
}
