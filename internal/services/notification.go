package services

import "context"

// Severity represents the severity level of a notification.
type Severity int

const (
	SeverityInfo Severity = iota
	SeverityWarning
	SeverityCritical
)

// String returns the string representation of the severity.
func (s Severity) String() string {
	switch s {
	case SeverityInfo:
		return "info"
	case SeverityWarning:
		return "warning"
	case SeverityCritical:
		return "critical"
	default:
		return "unknown"
	}
}

// NotificationService defines the interface for sending notifications across
// all domains (GitOps, Observability, Backup, etc.). This replaces the
// fragmented notify.sh + direct Telegram API calls pattern.
type NotificationService interface {
	// SendAlert sends a severity-rated alert to the configured notification channel.
	SendAlert(ctx context.Context, severity Severity, title, message string) error

	// SendDeploymentResult sends a deployment status notification.
	SendDeploymentResult(ctx context.Context, result DeploymentResult) error

	// SendHealthAlert sends a health check failure notification.
	SendHealthAlert(ctx context.Context, component string, healthy bool, details string) error
}

// DeploymentResult contains the result of a deployment operation.
type DeploymentResult struct {
	Host      string
	Success   bool
	Commit    string
	Branch    string
	Duration  string
	Changelog string
	Error     string
}
