package handlers

import (
	"context"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type TailscaleCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewTailscaleCommand(api *telegram.API, svc *services.Container) *TailscaleCommand {
	return &TailscaleCommand{api: api, svc: svc}
}

func (c *TailscaleCommand) Name() string                      { return "tailscale" }
func (c *TailscaleCommand) Description() string               { return "Show Tailscale status" }
func (c *TailscaleCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *TailscaleCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	lines := c.svc.Tailscale.FormatStatus()
	return c.api.SendLongMessage(msg.ChatID, strings.Join(lines, "\n"), 3500)
}
