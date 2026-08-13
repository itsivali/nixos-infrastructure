package handlers

import (
	"context"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// CancelCommand clears the user's pending confirmation prompts (the
// destructive-action confirmation is one-shot and user-bound; /cancel aborts
// it before it is confirmed).
type CancelCommand struct {
	api *telegram.API
}

// NewCancelCommand creates a new CancelCommand.
func NewCancelCommand(api *telegram.API) *CancelCommand {
	return &CancelCommand{api: api}
}

func (c *CancelCommand) Name() string                      { return "cancel" }
func (c *CancelCommand) Description() string               { return "Cancel pending operations" }
func (c *CancelCommand) RequiredPermission() telegram.Role { return telegram.RoleGuest }

func (c *CancelCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	CancelConfirmations(msg.UserID, msg.ChatID)
	return c.api.SendMarkdown(msg.ChatID, "No pending operations.")
}
