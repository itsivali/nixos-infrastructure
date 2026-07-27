package handlers

import (
	"context"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type FirewallCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewFirewallCommand(api *telegram.API, svc *services.Container) *FirewallCommand {
	return &FirewallCommand{api: api, svc: svc}
}

func (c *FirewallCommand) Name() string                      { return "firewall" }
func (c *FirewallCommand) Description() string               { return "Show firewall status" }
func (c *FirewallCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *FirewallCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	lines := c.svc.Firewall.FormatStatus()
	return c.api.SendLongMessage(msg.ChatID, strings.Join(lines, "\n"), 3500)
}
