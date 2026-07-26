package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// StateCommand shows platform state engine status.
type StateCommand struct {
	api *telegram.API
}

func NewStateCommand(config *telegram.Config) *StateCommand {
	return &StateCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *StateCommand) Name() string                      { return "state" }
func (c *StateCommand) Description() string               { return "Show platform state engine" }
func (c *StateCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *StateCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("ivali health --system 2>&1 || echo 'ivali not available'", 30)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

// EventsCommand shows recent event history.
type EventsCommand struct {
	api *telegram.API
}

func NewEventsCommand(config *telegram.Config) *EventsCommand {
	return &EventsCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *EventsCommand) Name() string                      { return "events" }
func (c *EventsCommand) Description() string               { return "Show recent events" }
func (c *EventsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *EventsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("ivali status 2>&1 | grep -A 20 'Events' || echo 'No events available'", 15)
	if strings.TrimSpace(output) == "" || strings.Contains(output, "No events") {
		return c.api.SendMarkdown(msg.ChatID, "*Event Log*\n\n`No recent events recorded.`")
	}
	return c.api.SendLongMessage(msg.ChatID, "*Event Log*\n\n```"+output+"```", 3500)
}

// PluginsCommand shows plugin registry status.
type PluginsCommand struct {
	api *telegram.API
}

func NewPluginsCommand(config *telegram.Config) *PluginsCommand {
	return &PluginsCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *PluginsCommand) Name() string                      { return "plugins" }
func (c *PluginsCommand) Description() string               { return "Show plugin status" }
func (c *PluginsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *PluginsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Plugin Registry*")
	lines = append(lines, "")

	plugins := []string{
		"bitwarden", "security", "gitops", "telegram",
		"observability", "recovery", "desktop", "developer", "ai",
	}

	for _, p := range plugins {
		output := runCmd(fmt.Sprintf("ivali health --system 2>&1 | grep -i '%s' || echo 'unknown'", p), 5)
		output = strings.TrimSpace(output)
		if output == "" || output == "unknown" {
			lines = append(lines, fmt.Sprintf("`%-15s` ✗ not loaded", p))
		} else {
			lines = append(lines, fmt.Sprintf("`%-15s` ✓ %s", p, output))
		}
	}

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

// InventoryCommand shows host inventory.
type InventoryCommand struct {
	api *telegram.API
}

func NewInventoryCommand(config *telegram.Config) *InventoryCommand {
	return &InventoryCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *InventoryCommand) Name() string                      { return "inventory" }
func (c *InventoryCommand) Description() string               { return "Show host inventory" }
func (c *InventoryCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *InventoryCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "*Collecting inventory...*")

	output := runCmd("ivali inventory 2>&1 || echo 'ivali not available'", 30)
	return c.api.SendLongMessage(msg.ChatID, "*Host Inventory*\n\n```"+output+"```", 3500)
}
