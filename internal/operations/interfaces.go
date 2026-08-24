package operations

import "context"

// DeploymentService manages NixOS deployments.
type DeploymentService interface {
	// Deploy triggers a deployment to a specific commit or the latest.
	Deploy(ctx context.Context, opts DeployOpts) (*DeploymentRecord, error)

	// Rollback reverts to a specific or previous NixOS generation.
	Rollback(ctx context.Context, opts RollbackOpts) (*RollbackResult, error)

	// Status returns the current deployment status.
	Status(ctx context.Context) (*DeploymentRecord, error)

	// History returns recent deployment records.
	History(ctx context.Context, limit int) ([]DeploymentRecord, error)

	// AcquireLock attempts to acquire the deployment lock.
	AcquireLock(ctx context.Context) (func(), error)
}

// HealthService provides structured health checks.
type HealthService interface {
	// Check performs a comprehensive health check.
	Check(ctx context.Context) (*OverallHealth, error)

	// CheckComponent checks a specific component by name.
	CheckComponent(ctx context.Context, name string) (*ComponentHealth, error)
}

// DriftService detects configuration drift.
type DriftService interface {
	// Detect checks for drift between desired and actual state.
	Detect(ctx context.Context) (*DriftReport, error)
}

// GenerationService manages NixOS generations.
type GenerationService interface {
	// List returns all available NixOS generations.
	List(ctx context.Context) ([]Generation, error)

	// Current returns the currently active generation.
	Current(ctx context.Context) (*Generation, error)
}

// ServiceManager provides systemd service operations.
type ServiceManager interface {
	// List returns the status of critical services.
	List(ctx context.Context) ([]ServiceStatus, error)

	// Status returns the status of a specific service.
	Status(ctx context.Context, name string) (*ServiceStatus, error)

	// Restart restarts a specific service.
	Restart(ctx context.Context, name string) error
}

// AuditLogger records operational actions.
type AuditLogger interface {
	// Log records an audit entry.
	Log(ctx context.Context, entry AuditEntry) error

	// Query returns audit entries matching the given criteria.
	Query(ctx context.Context, limit int, action string) ([]AuditEntry, error)
}
