package services

import "context"

// PlatformService defines the interface for platform-level operations.
// This replaces the pattern of shelling out to `ivali` CLI commands.
type PlatformService interface {
	// Health returns the platform health status.
	Health(ctx context.Context) (*PlatformHealth, error)

	// Status returns the repository and configuration status.
	Status(ctx context.Context) (*PlatformStatus, error)

	// Doctor runs diagnostics and returns a report.
	Doctor(ctx context.Context) (*DiagnosticReport, error)

	// Rebuild triggers a NixOS system rebuild for the specified host.
	Rebuild(ctx context.Context, host string) (string, error)

	// Rollback reverts to the previous NixOS generation.
	Rollback(ctx context.Context) (string, error)
}

// PlatformHealth represents the platform health status.
type PlatformHealth struct {
	Healthy bool
	Plugins []PluginHealth
	Message string
}

// PluginHealth represents the health of a single plugin.
type PluginHealth struct {
	Name    string
	State   string
	Message string
}

// PlatformStatus represents the repository and configuration status.
type PlatformStatus struct {
	RepoRoot      string
	CurrentGen    int
	Branch        string
	LastCommit    string
	ModifiedFiles int
}

// DiagnosticReport contains the results of a diagnostic check.
type DiagnosticReport struct {
	Checks []DiagnosticCheck
	Passed int
	Failed int
}

// DiagnosticCheck represents a single diagnostic check result.
type DiagnosticCheck struct {
	Name    string
	Passed  bool
	Message string
}
