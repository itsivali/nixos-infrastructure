package telegram

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// Runner is the main bot event loop.
type Runner struct {
	bot    *Bot
	api    *API
	config *Config
	logger Logger
}

// NewRunner creates a new bot runner.
func NewRunner(config *Config, logger Logger) *Runner {
	api := NewAPI(config.BotToken)
	auth := NewAuth(config.StateDir)
	bot := New(api, auth, logger)

	return &Runner{
		bot:    bot,
		api:    api,
		config: config,
		logger: logger,
	}
}

// Bot returns the bot instance for command registration.
func (r *Runner) Bot() *Bot {
	return r.bot
}

// Run starts the bot event loop.
func (r *Runner) Run(ctx context.Context) error {
	// Ensure state directory exists
	if err := os.MkdirAll(r.config.StateDir, 0o755); err != nil {
		return fmt.Errorf("create state dir: %w", err)
	}

	// Load offset from disk
	offset := r.loadOffset()

	// Register commands with Telegram
	if err := r.registerCommands(); err != nil {
		r.logger.Error("failed to register commands", "error", err)
	}

	r.logger.Info("bot started", "host", r.config.Hostname, "chat", r.config.ChatID)

	// Handle graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)

	for {
		select {
		case <-ctx.Done():
			r.logger.Info("bot shutting down (context cancelled)")
			return nil
		case sig := <-sigCh:
			r.logger.Info("bot shutting down", "signal", sig)
			return nil
		default:
		}

		updates, err := r.api.GetUpdates(offset, 60)
		if err != nil {
			r.logger.Error("failed to get updates", "error", err)
			time.Sleep(5 * time.Second)
			continue
		}

		// Heartbeat for the dead-man's-switch watchdog (#5): the bot
		// writes a timestamp on every successful poll so the watchdog
		// can alert if polling ever stops.
		_ = os.WriteFile("/run/ivali-bot/heartbeat",
			[]byte(strconv.FormatInt(time.Now().Unix(), 10)), 0o644)

		for _, update := range updates {
			r.handleUpdate(ctx, &update)
			offset = update.UpdateID + 1
			r.saveOffset(offset)
		}
	}
}

// handleUpdate processes a single Telegram update.
func (r *Runner) handleUpdate(ctx context.Context, update *Update) {
	// Handle callback queries
	if update.CallbackQuery != nil {
		r.handleCallback(ctx, update.CallbackQuery)
		return
	}

	// Handle messages
	if update.Message == nil {
		return
	}

	msg := update.Message

	// Skip empty messages
	if msg.Text == "" {
		return
	}

	// Skip stale messages
	if !r.isRecent(msg.Date) {
		r.logger.Debug("skipping stale message", "age", time.Since(time.Unix(msg.Date, 0)))
		return
	}

	// Check chat authorization
	if msg.Chat.ID != r.config.ChatID {
		r.logger.Info("unauthorized chat", "chat", msg.Chat.ID)
		return
	}

	// Build message struct
	botMsg := &Message{
		UpdateID: update.UpdateID,
		ChatID:   msg.Chat.ID,
		UserID:   msg.From.ID,
		Username: msg.From.Username,
		Text:     msg.Text,
		Date:     msg.Date,
	}

	// Dispatch to command handler
	if err := r.bot.Dispatch(ctx, botMsg); err != nil {
		r.logger.Error("command dispatch failed", "error", err, "command", botMsg.Command)
	}
}

// handleCallback processes a callback query from an inline keyboard.
func (r *Runner) handleCallback(ctx context.Context, query *CallbackQuery) {
	if query.Chat == nil || query.Chat.ID != r.config.ChatID {
		return
	}

	botMsg := &Message{
		ChatID:          query.Chat.ID,
		UserID:          query.From.ID,
		Username:        query.From.Username,
		IsCallback:      true,
		CallbackID:      query.ID,
		CallbackPayload: query.Data,
	}

	// Store callback data for handler access
	// This is a simple approach - in production you'd use a proper field
	_ = query.Data

	if err := r.bot.Dispatch(ctx, botMsg); err != nil {
		r.logger.Error("callback dispatch failed", "error", err)
	}
}

// registerCommands registers all bot commands with the Telegram API.
func (r *Runner) registerCommands() error {
	cmds := r.bot.GetCommands()
	infos := make([]CommandInfo, len(cmds))
	for i, cmd := range cmds {
		infos[i] = CommandInfo{
			Name:        cmd.Name(),
			Description: cmd.Description(),
		}
	}
	return r.api.RegisterCommands(infos)
}

// isRecent checks if a timestamp is within the max age.
func (r *Runner) isRecent(timestamp int64) bool {
	age := time.Since(time.Unix(timestamp, 0))
	return age <= time.Duration(r.config.MaxAgeSecs)*time.Second
}

// loadOffset reads the persisted update offset from disk.
func (r *Runner) loadOffset() int {
	data, err := os.ReadFile(filepath.Join(r.config.StateDir, "offset"))
	if err != nil {
		return 0
	}
	offset, err := strconv.Atoi(strings.TrimSpace(string(data)))
	if err != nil {
		return 0
	}
	return offset
}

// saveOffset persists the update offset to disk.
func (r *Runner) saveOffset(offset int) {
	path := filepath.Join(r.config.StateDir, "offset")
	tmpPath := path + ".tmp"

	data := []byte(strconv.Itoa(offset))
	if err := os.WriteFile(tmpPath, data, 0o644); err != nil {
		r.logger.Error("failed to save offset", "error", err)
		return
	}

	if err := os.Rename(tmpPath, path); err != nil {
		r.logger.Error("failed to rename offset file", "error", err)
	}
}
