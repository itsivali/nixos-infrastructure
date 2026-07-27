package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/renderer"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type StateCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewStateCommand(api *telegram.API, svc *services.Container) *StateCommand {
	return &StateCommand{api: api, svc: svc}
}

func (c *StateCommand) Name() string                      { return "state" }
func (c *StateCommand) Description() string               { return "Show platform state engine" }
func (c *StateCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *StateCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Platform.Health()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type EventsCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewEventsCommand(api *telegram.API, svc *services.Container) *EventsCommand {
	return &EventsCommand{api: api, svc: svc}
}

func (c *EventsCommand) Name() string                      { return "events" }
func (c *EventsCommand) Description() string               { return "Show recent events" }
func (c *EventsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *EventsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Platform.Events()
	if output == "" {
		return c.api.SendMarkdown(msg.ChatID, "*Event Log*\n\n`No recent events recorded.`")
	}
	return c.api.SendLongMessage(msg.ChatID, "*Event Log*\n\n"+renderer.CodeBlock(output), 3500)
}

type PluginsCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewPluginsCommand(api *telegram.API, svc *services.Container) *PluginsCommand {
	return &PluginsCommand{api: api, svc: svc}
}

func (c *PluginsCommand) Name() string                      { return "plugins" }
func (c *PluginsCommand) Description() string               { return "Show plugin status" }
func (c *PluginsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *PluginsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Plugin Registry*")
	lines = append(lines, "")

	plugins := c.svc.Platform.Plugins()
	for _, p := range plugins {
		if p.Loaded {
			lines = append(lines, fmt.Sprintf("`%-15s` ✓ %s", p.Name, p.Detail))
		} else {
			lines = append(lines, fmt.Sprintf("`%-15s` ✗ not loaded", p.Name))
		}
	}

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

type InventoryCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewInventoryCommand(api *telegram.API, svc *services.Container) *InventoryCommand {
	return &InventoryCommand{api: api, svc: svc}
}

func (c *InventoryCommand) Name() string                      { return "inventory" }
func (c *InventoryCommand) Description() string               { return "Show host inventory" }
func (c *InventoryCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *InventoryCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "*Collecting inventory...*")
	output := c.svc.Platform.Inventory()
	return c.api.SendLongMessage(msg.ChatID, "*Host Inventory*\n\n"+renderer.CodeBlock(output), 3500)
}
