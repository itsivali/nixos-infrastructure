package services

// Registry holds all service implementations for dependency injection.
// This replaces the scattered service initialization across different packages.
type Registry struct {
	Notification NotificationService
	Backup       BackupService
	Metrics      MetricsProvider
	Health       HealthChecker
	Platform     PlatformService
}

// NewRegistry creates a new service registry with the given implementations.
func NewRegistry(
	notification NotificationService,
	backup BackupService,
	metrics MetricsProvider,
	health HealthChecker,
	platform PlatformService,
) *Registry {
	return &Registry{
		Notification: notification,
		Backup:       backup,
		Metrics:      metrics,
		Health:       health,
		Platform:     platform,
	}
}
