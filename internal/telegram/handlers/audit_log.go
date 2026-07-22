package handlers

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// AuditLogger writes structured command audit records to the system
// journal via systemd-cat.  Every command execution is logged with
// metadata useful for security review and debugging.
type AuditLogger struct {
	identifier string
}

// NewAuditLogger creates an AuditLogger that tags journal entries with
// the given identifier (typically "ivali-bot").
func NewAuditLogger(identifier string) *AuditLogger {
	if identifier == "" {
		identifier = "ivali-bot"
	}
	return &AuditLogger{identifier: identifier}
}

// Log records a command execution to the system journal.
//
// Fields written to the journal:
//   - timestamp:   RFC3339Nano of the execution
//   - user_id:     Telegram user ID
//   - chat_id:     Telegram chat ID
//   - command:     command name (without leading slash)
//   - args:        raw arguments string
//   - success:     whether the command completed without error
//   - duration_ms: wall-clock execution time in milliseconds
func (al *AuditLogger) Log(userID int64, chatID int64, cmd, args string, success bool, durationMs int64) {
	entry := al.formatEntry(userID, chatID, cmd, args, success, durationMs)
	al.writeJournal(entry)
}

// formatEntry produces a single-line structured log entry.
func (al *AuditLogger) formatEntry(userID int64, chatID int64, cmd, args string, success bool, durationMs int64) string {
	successStr := "true"
	if !success {
		successStr = "false"
	}

	// Sanitize args to a single line (replace newlines with spaces).
	args = strings.ReplaceAll(args, "\n", " ")
	args = strings.TrimSpace(args)
	if args == "" {
		args = "-"
	}

	return fmt.Sprintf(
		"timestamp=%s user_id=%d chat_id=%d command=%s args=%q success=%s duration_ms=%d",
		time.Now().Format(time.RFC3339Nano),
		userID,
		chatID,
		cmd,
		args,
		successStr,
		durationMs,
	)
}

// writeJournal pipes the entry to systemd-cat.
func (al *AuditLogger) writeJournal(entry string) {
	cmd := exec.Command("systemd-cat", "-t", al.identifier, "-p", "info")
	cmd.Stdin = strings.NewReader(entry + "\n")
	// Best-effort: ignore errors since audit logging must never block
	// command execution or cause panics.
	_ = cmd.Run()
}
