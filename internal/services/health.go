package services

import "context"

// HealthChecker defines the interface for system health checks.
// This unifies the three independent health check implementations:
// deployment-health.sh, health-endpoint.nix, and internal/platform/health.
type HealthChecker interface {
	// CheckSystem performs a full system health check.
	CheckSystem(ctx context.Context) (*SystemHealth, error)

	// CheckServices checks the health of specific systemd services.
	CheckServices(ctx context.Context, services []string) (map[string]ServiceHealth, error)

	// CheckNetwork checks network connectivity (Tailscale, internet, DNS).
	CheckNetwork(ctx context.Context) (*NetworkHealth, error)

	// CheckDisk checks disk usage for specified mount points.
	CheckDisk(ctx context.Context, mounts []string) (map[string]DiskHealth, error)

	// CheckDeploymentHealth runs deployment-health.sh and returns structured results.
	CheckDeploymentHealth(ctx context.Context) (*DeploymentHealth, error)
}

// SystemHealth represents the overall system health status.
type SystemHealth struct {
	Healthy  bool
	Services map[string]ServiceHealth
	Network  *NetworkHealth
	Disk     map[string]DiskHealth
	NixOSGen int
	Message  string
}

// NetworkHealth represents network connectivity status.
type NetworkHealth struct {
	Tailscale bool
	Internet  bool
	DNS       bool
	Message   string
}

// DiskHealth represents disk usage for a mount point.
type DiskHealth struct {
	Mount       string
	UsedPercent float64
	Available   uint64
	Total       uint64
	Message     string
}

// DeploymentHealth represents the full deployment-health.sh results.
type DeploymentHealth struct {
	Timestamp    string            `json:"timestamp"`
	Host         string            `json:"host"`
	StrictHealth bool              `json:"strict_health"`
	Passed       int               `json:"passed"`
	Warned       int               `json:"warned"`
	Failed       int               `json:"failed"`
	Total        int               `json:"total"`
	Duration     int               `json:"duration_seconds"`
	Healthy      bool              `json:"-"`
	Checks       []DeploymentCheck `json:"checks"`
}

// DeploymentCheck represents a single check result from deployment-health.sh.
type DeploymentCheck struct {
	Name    string `json:"name"`
	Status  string `json:"status"`
	Message string `json:"message"`
}
