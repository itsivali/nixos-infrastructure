package impl

import (
	"context"
	"fmt"
	"os/exec"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/services"
)

// EmailNotification implements services.NotificationService by sending
// messages through the shared notify.sh script (email-only).
type EmailNotification struct {
	notifyScript string
}

// NewEmailNotification creates a notification service backed by notify.sh.
func NewEmailNotification(notifyScript string) *EmailNotification {
	return &EmailNotification{notifyScript: notifyScript}
}

func (t *EmailNotification) SendAlert(ctx context.Context, severity services.Severity, title, message string) error {
	prefix := fmt.Sprintf("[%s]", strings.ToUpper(severity.String()))
	text := fmt.Sprintf("%s %s\n\n%s", prefix, title, message)
	return t.send(ctx, text)
}

func (t *EmailNotification) SendDeploymentResult(ctx context.Context, result services.DeploymentResult) error {
	status := "succeeded"
	if !result.Success {
		status = "failed"
	}

	var b strings.Builder
	fmt.Fprintf(&b, "Deploy %s on %s\n", status, result.Host)

	if result.Commit != "" {
		fmt.Fprintf(&b, "Commit: %s\n", result.Commit[:min(8, len(result.Commit))])
	}
	if result.Branch != "" {
		fmt.Fprintf(&b, "Branch: %s\n", result.Branch)
	}
	if result.Duration != "" {
		fmt.Fprintf(&b, "Duration: %s\n", result.Duration)
	}
	if result.Changelog != "" {
		fmt.Fprintf(&b, "\n%s", result.Changelog)
	}
	if result.Error != "" {
		fmt.Fprintf(&b, "\nError: %s", result.Error)
	}

	return t.send(ctx, b.String())
}

func (t *EmailNotification) SendHealthAlert(ctx context.Context, component string, healthy bool, details string) error {
	status := "healthy"
	if !healthy {
		status = "unhealthy"
	}
	text := fmt.Sprintf("Health: %s is %s", component, status)
	if details != "" {
		text += "\n" + details
	}
	return t.send(ctx, text)
}

func (t *EmailNotification) send(ctx context.Context, message string) error {
	cmd := exec.CommandContext(ctx, "/bin/sh", t.notifyScript, message)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("notify failed: %w: %s", err, string(out))
	}
	return nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
