// Package telegram provides a Telegram bot for NixOS infrastructure management.
package telegram

import (
	"context"
	"fmt"
	"strings"
	"time"
)

// Role represents a user permission level.
type Role int

const (
	RoleGuest Role = iota
	RoleUser
	RoleAdmin
	RoleOwner
)

func (r Role) String() string {
	switch r {
	case RoleOwner:
		return "owner"
	case RoleAdmin:
		return "admin"
	case RoleUser:
		return "user"
	case RoleGuest:
		return "guest"
	default:
		return "unknown"
	}
}

// ParseRole converts a string to a Role.
func ParseRole(s string) Role {
	switch strings.ToLower(s) {
	case "owner":
		return RoleOwner
	case "admin":
		return RoleAdmin
	case "user":
		return RoleUser
	case "guest":
		return RoleGuest
	default:
		return RoleGuest
	}
}

// HasPermission checks if the role has sufficient permissions.
func (r Role) HasPermission(required Role) bool {
	return r >= required
}

// Message represents an incoming Telegram message.
type Message struct {
	UpdateID        int
	ChatID          int64
	UserID          int
	Username        string
	Text            string
	Command         string
	Args            string
	Date            int64
	IsCallback      bool
	CallbackID      string
	CallbackPayload string
	MessageID       int
}

// Command defines a bot command handler.
type Command interface {
	// Name returns the command name without the leading slash.
	Name() string

	// Description returns a short description for the help text.
	Description() string

	// Execute runs the command with the given message.
	Execute(ctx context.Context, msg *Message) error

	// RequiredPermission returns the minimum role required to use this command.
	RequiredPermission() Role
}

// CommandFunc is a helper type for adapting functions to the Command interface.
type CommandFunc struct {
	name        string
	description string
	handler     func(ctx context.Context, msg *Message) error
	permission  Role
}

// NewCommandFunc creates a new command from a function.
func NewCommandFunc(name, description string, permission Role, handler func(ctx context.Context, msg *Message) error) *CommandFunc {
	return &CommandFunc{
		name:        name,
		description: description,
		handler:     handler,
		permission:  permission,
	}
}

func (c *CommandFunc) Name() string             { return c.name }
func (c *CommandFunc) Description() string      { return c.description }
func (c *CommandFunc) RequiredPermission() Role { return c.permission }
func (c *CommandFunc) Execute(ctx context.Context, msg *Message) error {
	return c.handler(ctx, msg)
}

// CallbackHandler handles inline keyboard callback queries.
type CallbackHandler interface {
	HandleCallback(ctx context.Context, queryID string, chatID int64, userID int, data string) error
}

// Bot is the main Telegram bot controller.
type Bot struct {
	commands  map[string]Command
	callbacks map[string]CallbackHandler
	api       *API
	auth      *Auth
	logger    Logger
	// beforeExec is an optional hook called before command execution.
	// Return false to block the command. userID and chatID identify the
	// source; cmdName is the command being dispatched.
	beforeExec func(userID int, chatID int64, cmdName string) bool
	// afterExec is an optional hook called after command execution with
	// timing and success information for audit logging.
	afterExec func(userID int, chatID int64, cmdName string, args string, success bool, durationMs int64)
}

// Logger is the interface for bot logging.
type Logger interface {
	Info(msg string, args ...any)
	Error(msg string, args ...any)
	Debug(msg string, args ...any)
}

// New creates a new Bot instance.
func New(api *API, auth *Auth, logger Logger) *Bot {
	return &Bot{
		commands:  make(map[string]Command),
		callbacks: make(map[string]CallbackHandler),
		api:       api,
		auth:      auth,
		logger:    logger,
	}
}

// RegisterCommand adds a command to the bot.
func (b *Bot) RegisterCommand(cmd Command) {
	b.commands[cmd.Name()] = cmd
}

// RegisterCommands adds multiple commands to the bot.
func (b *Bot) RegisterCommands(cmds ...Command) {
	for _, cmd := range cmds {
		b.RegisterCommand(cmd)
	}
}

// RegisterCallback registers a callback handler for a prefix.
func (b *Bot) RegisterCallback(prefix string, handler CallbackHandler) {
	b.callbacks[prefix] = handler
}

// GetCommands returns all registered commands sorted by name.
func (b *Bot) GetCommands() []Command {
	cmds := make([]Command, 0, len(b.commands))
	for _, cmd := range b.commands {
		cmds = append(cmds, cmd)
	}
	return cmds
}

// API returns the Telegram API client.
func (b *Bot) API() *API {
	return b.api
}

// Auth returns the authentication manager.
func (b *Bot) Auth() *Auth {
	return b.auth
}

// SetBeforeExec sets an optional hook called before command execution.
// Return false from the hook to block the command.
func (b *Bot) SetBeforeExec(hook func(userID int, chatID int64, cmdName string) bool) {
	b.beforeExec = hook
}

// SetAfterExec sets an optional hook called after command execution.
// Used for audit logging with timing and success information.
func (b *Bot) SetAfterExec(hook func(userID int, chatID int64, cmdName string, args string, success bool, durationMs int64)) {
	b.afterExec = hook
}

// CommandByName returns a registered command by name.
func (b *Bot) CommandByName(name string) (Command, bool) {
	cmd, ok := b.commands[name]
	return cmd, ok
}

// Dispatch processes an incoming message and routes it to the appropriate handler.
func (b *Bot) Dispatch(ctx context.Context, msg *Message) error {
	// Handle callback queries
	if msg.IsCallback {
		return b.dispatchCallback(ctx, msg)
	}

	// Parse command from text
	if !strings.HasPrefix(msg.Text, "/") {
		return nil
	}

	parts := strings.SplitN(strings.TrimPrefix(msg.Text, "/"), " ", 2)
	cmdName := strings.ToLower(parts[0])
	args := ""
	if len(parts) > 1 {
		args = parts[1]
	}

	msg.Command = cmdName
	msg.Args = args

	// Find command handler
	cmd, ok := b.commands[cmdName]
	if !ok {
		return b.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Unknown command: /%s\nType /help for available commands.", cmdName))
	}

	// Check permissions
	userRole := b.auth.GetUserRole(msg.UserID)
	if !userRole.HasPermission(cmd.RequiredPermission()) {
		return b.api.SendMarkdown(msg.ChatID, fmt.Sprintf(
			"*Permission Denied*\n\nRequired: *%s*\nYour role: *%s*\n\nContact the system owner to request access.",
			cmd.RequiredPermission(), userRole,
		))
	}

	b.logger.Info("command executed", "command", cmdName, "user", msg.Username, "chat", msg.ChatID)

	// Optional rate-limiting / permission hook
	if b.beforeExec != nil && !b.beforeExec(msg.UserID, msg.ChatID, cmdName) {
		return b.api.SendMarkdown(msg.ChatID, "Command blocked by rate limiter.")
	}

	start := time.Now()
	err := cmd.Execute(ctx, msg)
	durationMs := time.Since(start).Milliseconds()

	if b.afterExec != nil {
		b.afterExec(msg.UserID, msg.ChatID, cmdName, msg.Args, err == nil, durationMs)
	}

	return err
}

// dispatchCallback routes callback queries to registered handlers.
func (b *Bot) dispatchCallback(ctx context.Context, msg *Message) error {
	for prefix, handler := range b.callbacks {
		if strings.HasPrefix(msg.CallbackData(), prefix) {
			return handler.HandleCallback(ctx, msg.CallbackID, msg.ChatID, msg.UserID, msg.CallbackData())
		}
	}

	// Answer the callback query to dismiss the loading indicator
	return b.api.AnswerCallback(msg.CallbackID, "")
}

// CallbackData returns the inline-keyboard callback payload, if any.
func (m *Message) CallbackData() string {
	return m.CallbackPayload
}
