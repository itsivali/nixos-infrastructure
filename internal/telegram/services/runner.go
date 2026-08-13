// Package services provides reusable business logic for the Telegram bot.
// Handlers delegate to these services instead of executing shell commands directly.
package services

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"strings"
	"time"
)

// Runner executes shell commands with timeout and captures output.
type Runner struct {
	defaultUser string
}

// NewRunner creates a new command Runner.
func NewRunner() *Runner {
	u := os.Getenv("DEFAULT_USER")
	if u == "" {
		u = "ivali"
	}
	return &Runner{defaultUser: u}
}

// Run executes a shell command via sh -c with a timeout.
func (r *Runner) Run(command string, timeoutSecs int) string {
	return r.RunWithContext(context.Background(), command, timeoutSecs)
}

// RunWithContext executes a shell command with a parent context for cancellation.
func (r *Runner) RunWithContext(ctx context.Context, command string, timeoutSecs int) string {
	ctx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSecs)*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "sh", "-c", command)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	output := stdout.String()
	if stderr.Len() > 0 {
		if output != "" {
			output += "\n"
		}
		output += stderr.String()
	}

	if ctx.Err() == context.DeadlineExceeded {
		return fmt.Sprintf("Command timed out after %ds", timeoutSecs)
	}

	if err != nil && output == "" {
		return "Error: " + err.Error()
	}

	return output
}

// RunArgs executes a command directly (no shell) with a timeout.
// This prevents shell injection from user-supplied arguments.
func (r *Runner) RunArgs(timeoutSecs int, args ...string) string {
	return r.RunArgsWithContext(context.Background(), timeoutSecs, args...)
}

// RunArgsWithContext executes a command directly with a parent context.
func (r *Runner) RunArgsWithContext(ctx context.Context, timeoutSecs int, args ...string) string {
	if len(args) == 0 {
		return ""
	}

	ctx, cancel := context.WithTimeout(ctx, time.Duration(timeoutSecs)*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	output := stdout.String()
	if stderr.Len() > 0 {
		if output != "" {
			output += "\n"
		}
		output += stderr.String()
	}

	if ctx.Err() == context.DeadlineExceeded {
		return fmt.Sprintf("Command timed out after %ds", timeoutSecs)
	}

	if err != nil && output == "" {
		return "Error: " + err.Error()
	}

	return output
}

// RunAsUser executes a shell command as the interactive desktop user with
// Wayland/D-Bus session environment, so GUI automation works from root.
func (r *Runner) RunAsUser(command string, timeoutSecs int) string {
	return r.RunAsUserWithContext(context.Background(), command, timeoutSecs)
}

// RunAsUserWithContext executes a shell command as the desktop user with parent context.
func (r *Runner) RunAsUserWithContext(ctx context.Context, command string, timeoutSecs int) string {
	targetUser := r.defaultUser
	uid := "1000"
	if u, err := user.Lookup(targetUser); err == nil && u.Uid != "" {
		uid = u.Uid
	}
	xdg := "/run/user/" + uid
	if _, err := os.Stat(xdg); os.IsNotExist(err) {
		return fmt.Sprintf("🖥 DESKTOP UNAVAILABLE\n\nNo active graphical user session found at %s for user %s.", xdg, targetUser)
	}

	dbus := "unix:path=" + xdg + "/bus"
	inner := fmt.Sprintf(
		"export PATH=/run/current-system/sw/bin:/run/wrappers/bin:/usr/bin:/bin "+
			"XDG_RUNTIME_DIR=%s DBUS_SESSION_BUS_ADDRESS=%s WAYLAND_DISPLAY=wayland-0 DISPLAY=:0; %s",
		xdg, dbus, command,
	)
	full := "sudo -u " + targetUser + " sh -c " + QuoteSh(inner)
	return r.RunWithContext(ctx, full, timeoutSecs)
}

// QuoteSh single-quotes a string for safe embedding in sh -c '...'.
func QuoteSh(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

// RunRetry executes a command with retries on failure.
// It attempts the command up to maxAttempts times, sleeping between retries.
func (r *Runner) RunRetry(command string, timeoutSecs, maxAttempts int) string {
	return r.RunRetryWithContext(context.Background(), command, timeoutSecs, maxAttempts)
}

// RunRetryWithContext executes a command with retries and parent context.
func (r *Runner) RunRetryWithContext(ctx context.Context, command string, timeoutSecs, maxAttempts int) string {
	if maxAttempts <= 0 {
		maxAttempts = 1
	}

	var lastOutput string
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		if ctx.Err() != nil {
			return "Command cancelled"
		}

		lastOutput = r.RunWithContext(ctx, command, timeoutSecs)

		// If the output doesn't contain "Error:" or "timed out", treat as success
		if !strings.Contains(lastOutput, "Error:") && !strings.Contains(lastOutput, "timed out") {
			return lastOutput
		}

		if attempt < maxAttempts {
			// Exponential backoff: 1s, 2s, 4s...
			backoff := time.Duration(1<<(attempt-1)) * time.Second
			select {
			case <-ctx.Done():
				return "Command cancelled"
			case <-time.After(backoff):
			}
		}
	}

	return lastOutput
}
