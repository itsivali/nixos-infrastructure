package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// CmdCallbackHandler dispatches generic inline button callbacks prefixed with "cmd:".
type CmdCallbackHandler struct {
	bot *telegram.Bot
}

// NewCmdCallbackHandler creates a new generic command callback handler.
func NewCmdCallbackHandler(bot *telegram.Bot) *CmdCallbackHandler {
	return &CmdCallbackHandler{bot: bot}
}

// HandleCallback parses and dispatches "cmd:<name>" callback queries.
func (h *CmdCallbackHandler) HandleCallback(ctx context.Context, queryID string, chatID int64, userID int, data string, messageID int) error {
	api := h.bot.API()

	if !strings.HasPrefix(data, "cmd:") {
		return api.AnswerCallback(queryID, "Invalid callback")
	}

	payload := strings.TrimPrefix(data, "cmd:")
	parts := strings.SplitN(payload, ":", 2)
	cmdName := strings.ToLower(parts[0])
	args := ""
	if len(parts) > 1 {
		args = parts[1]
	}

	cmd, ok := h.bot.CommandByName(cmdName)
	if !ok {
		_ = api.AnswerCallback(queryID, "Unknown command: "+cmdName)
		return nil
	}

	userRole := h.bot.Auth().GetUserRole(userID)
	if !userRole.HasPermission(cmd.RequiredPermission()) {
		_ = api.AnswerCallback(queryID, fmt.Sprintf("Permission denied (requires %s)", cmd.RequiredPermission()))
		return nil
	}

	msg := &telegram.Message{
		ChatID:          chatID,
		UserID:          userID,
		Command:         cmdName,
		Args:            args,
		IsCallback:      true,
		CallbackPayload: data,
		CallbackID:      queryID,
		MessageID:       messageID,
	}

	// Dismiss loading indicator
	_ = api.AnswerCallback(queryID, "")

	// The command already sent (or edited) its own output — including
	// confirmation prompts for destructive actions — so do not append a
	// redundant "executed" card. Only surface genuine failures.
	if err := cmd.Execute(ctx, msg); err != nil {
		h.bot.API().SendMarkdown(chatID, fmt.Sprintf("🔴 *Command Failed: /%s*\n\n`%s`", cmdName, err.Error()))
		return err
	}
	return nil
}
