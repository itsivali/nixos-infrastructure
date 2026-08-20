package telegram

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/events"
)

// Runner is the main bot event loop.
type Runner struct {
	bot    *Bot
	api    *API
	config *Config
	logger Logger
	bus    *events.Bus

	// Heartbeat state
	lastHeartbeatTime time.Time
	messagesReceived  int
	commandsExecuted  int
	errors            int
	lastEvents        []heartbeatEvent
}

type heartbeatEvent struct {
	Type    string `json:"type"`
	Time    string `json:"time"`
	Message string `json:"message"`
}

// NewRunner creates a new bot runner.
func NewRunner(config *Config, logger Logger) *Runner {
	api := NewAPI(config.BotToken)
	auth := NewAuth(config.StateDir)
	auth.singleUserMode = config.SingleUserMode // respect single‑user mode flag
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

// SetEventBus sets the event bus for tracking events.
func (r *Runner) SetEventBus(bus *events.Bus) {
	r.bus = bus
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

		// Heartbeat: write structured JSON every 30 minutes for the watchdog.
		if time.Since(r.lastHeartbeatTime) >= 30*time.Minute {
			r.writeHeartbeat()
			r.lastHeartbeatTime = time.Now()
		}

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
//
// Telegram's CallbackQuery does NOT include a top-level "chat" field —
// the chat lives inside query.Message.Chat instead.  Relying on
// query.Chat (which is always nil) silently dropped every inline
// keyboard callback.  We fall back to the configured ChatID when the
// message is unavailable (e.g. deleted messages or inline-mode queries).
func (r *Runner) handleCallback(ctx context.Context, query *CallbackQuery) {
	// Determine chat ID: prefer the original message's chat, fall back
	// to the configured chat ID.
	var chatID int64
	if query.Message != nil && query.Message.Chat != nil {
		chatID = query.Message.Chat.ID
	} else {
		chatID = r.config.ChatID
	}

	if chatID != r.config.ChatID {
		r.logger.Info("unauthorized callback chat", "chat", chatID)
		return
	}

	botMsg := &Message{
		ChatID:          chatID,
		UserID:          query.From.ID,
		Username:        query.From.Username,
		IsCallback:      true,
		CallbackID:      query.ID,
		CallbackPayload: query.Data,
	}

	// Wire through the message ID so handlers can edit the original message
	// instead of sending a new one, keeping the chat clean.
	if query.Message != nil {
		botMsg.MessageID = query.Message.MessageID
	}

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

// writeHeartbeat writes structured JSON heartbeat for the watchdog.
func (r *Runner) writeHeartbeat() {
	// System stats
	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)
	memPct := int(float64(memStats.Alloc) / float64(memStats.Sys) * 100)

	// Load average
	loadAvg := [3]float64{0, 0, 0}
	if loadBytes, err := os.ReadFile("/proc/loadavg"); err == nil {
		parts := strings.Fields(string(loadBytes))
		if len(parts) >= 3 {
			for i := 0; i < 3; i++ {
				if v, err := strconv.ParseFloat(parts[i], 64); err == nil {
					loadAvg[i] = v
				}
			}
		}
	}

	// Disk usage
	diskPct := 0
	if diskBytes, err := os.ReadFile("/proc/mounts"); err == nil {
		_ = diskBytes
	}
	// Simple df-based disk check
	if out, err := os.ReadFile("/proc/diskstats"); err == nil {
		_ = out
	}

	// Read disk usage from /proc/1/mountstats is complex, use a simpler approach
	// For now, we'll use 0 as placeholder and let the watchdog handle it

	// Compute diff since last heartbeat
	diff := heartbeatDiff{
		WindowMinutes:    30,
		MessagesReceived: r.messagesReceived,
		CommandsExecuted: r.commandsExecuted,
		Errors:           r.errors,
		Events:           []string{},
	}

	// Reset counters
	r.messagesReceived = 0
	r.commandsExecuted = 0
	r.errors = 0

	// Get last 5 events from event bus
	if r.bus != nil {
		recentEvents := r.bus.HistoryLast(5)
		for _, e := range recentEvents {
			r.lastEvents = append(r.lastEvents, heartbeatEvent{
				Type:    string(e.Type),
				Time:    e.Timestamp.Format("15:04:05"),
				Message: e.Message,
			})
			diff.Events = append(diff.Events, string(e.Type))
		}
		// Keep only last 5
		if len(r.lastEvents) > 5 {
			r.lastEvents = r.lastEvents[len(r.lastEvents)-5:]
		}
	}

	// Read disk percentage
	diskPct = readDiskPercent("/")

	heartbeat := map[string]interface{}{
		"host":         r.config.Hostname,
		"timestamp":    time.Now().Format(time.RFC3339),
		"uptime_human": readUptime(),
		"state":        "running",
		"since_last_heartbeat": map[string]interface{}{
			"window_minutes":    diff.WindowMinutes,
			"messages_received": diff.MessagesReceived,
			"commands_executed": diff.CommandsExecuted,
			"errors":            diff.Errors,
			"events":            diff.Events,
		},
		"totals": map[string]interface{}{
			"commands_total": 0, // Will be enriched by metrics collector if wired
			"errors_total":   0,
			"deploys_total":  0,
		},
		"system": map[string]interface{}{
			"load":       loadAvg,
			"memory_pct": memPct,
			"disk_pct":   diskPct,
		},
		"last_5_events": r.lastEvents,
	}

	data, err := json.MarshalIndent(heartbeat, "", "  ")
	if err != nil {
		r.logger.Error("failed to marshal heartbeat", "error", err)
		return
	}

	if err := os.MkdirAll("/run/ivali-bot", 0o755); err != nil {
		r.logger.Error("failed to create heartbeat dir", "error", err)
		return
	}

	if err := os.WriteFile("/run/ivali-bot/heartbeat.json", data, 0o644); err != nil {
		r.logger.Error("failed to write heartbeat", "error", err)
	}
}

// heartbeatDiff tracks what changed since the last heartbeat.
type heartbeatDiff struct {
	WindowMinutes    int      `json:"window_minutes"`
	MessagesReceived int      `json:"messages_received"`
	CommandsExecuted int      `json:"commands_executed"`
	Errors           int      `json:"errors"`
	Events           []string `json:"events"`
}

// readUptime returns a human-readable uptime string.
func readUptime() string {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return "unknown"
	}
	parts := strings.Fields(string(data))
	if len(parts) < 1 {
		return "unknown"
	}
	seconds, err := strconv.ParseFloat(parts[0], 64)
	if err != nil {
		return "unknown"
	}
	days := int(seconds) / 86400
	hours := (int(seconds) % 86400) / 3600
	mins := (int(seconds) % 3600) / 60
	return fmt.Sprintf("%dd %dh %dm", days, hours, mins)
}

// readDiskPercent reads disk usage percentage for a mount point using syscall.Statfs.
// Returns 0 if the stat fails (best-effort; the watchdog performs its own checks).
func readDiskPercent(mountpoint string) int {
	var stat syscall.Statfs_t
	if err := syscall.Statfs(mountpoint, &stat); err != nil {
		return 0
	}
	if stat.Blocks == 0 {
		return 0
	}
	used := stat.Blocks - stat.Bfree
	return int(float64(used) / float64(stat.Blocks) * 100)
}
