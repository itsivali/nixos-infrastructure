package operations

import "time"

// DeploymentState represents the state of a deployment operation.
type DeploymentState string

const (
	StatePending            DeploymentState = "pending"
	StateValidating         DeploymentState = "validating"
	StateLocked             DeploymentState = "locked"
	StateResolving          DeploymentState = "resolving"
	StateBuilding           DeploymentState = "building"
	StateActivating         DeploymentState = "activating"
	StateVerifying          DeploymentState = "verifying"
	StateHealthy            DeploymentState = "healthy"
	StateComplete           DeploymentState = "complete"
	StateFailed             DeploymentState = "failed"
	StateRollbackRequired   DeploymentState = "rollback_required"
	StateRollingBack        DeploymentState = "rolling_back"
	StateVerifyingRollback  DeploymentState = "verifying_rollback"
	StateRecovered          DeploymentState = "recovered"
	StateDegraded           DeploymentState = "degraded"
	StateRolledBack         DeploymentState = "rolled_back"
)

// DeploymentRecord represents a completed or in-progress deployment.
type DeploymentRecord struct {
	ID                string          `json:"id"`
	CommitSHA         string          `json:"commit_sha"`
	PreviousSHA       string          `json:"previous_sha,omitempty"`
	ResolvedSHA       string          `json:"resolved_sha,omitempty"`
	ActualSHA         string          `json:"actual_sha,omitempty"`
	Generation        int             `json:"generation"`
	PreviousGen       int             `json:"previous_generation,omitempty"`
	Actor             string          `json:"actor"`
	Source            string          `json:"source"`
	Timestamp         time.Time       `json:"timestamp"`
	State             DeploymentState `json:"state"`
	Status            string          `json:"status"`
	Error             string          `json:"error,omitempty"`
	HealthResult      string          `json:"health_result,omitempty"`
	Duration          string          `json:"duration,omitempty"`
	Changelog         string          `json:"changelog,omitempty"`
	ChangedFiles      string          `json:"changed_files,omitempty"`
	Branch            string          `json:"branch,omitempty"`
	BuildInputSHA     string          `json:"build_input_sha,omitempty"`
	RollbackGen       int             `json:"rollback_generation,omitempty"`
	RecoveryAttempts  int             `json:"recovery_attempts,omitempty"`
}

// DeployOpts configures a deployment operation.
type DeployOpts struct {
	Commit string // specific commit SHA to deploy; empty = latest from branch
	Actor  string // who initiated (e.g., "ivali-cli", "gitops-reconciler", "web-ui")
	Source string // source of deployment (e.g., "gitops", "cli", "api")
}

// RollbackOpts configures a rollback operation.
type RollbackOpts struct {
	Generation int    // target generation; 0 = previous generation
	Actor      string // who initiated
	Reason     string // reason for rollback
}

// RollbackResult contains the result of a rollback operation.
type RollbackResult struct {
	Success       bool   `json:"success"`
	FromGen       int    `json:"from_generation"`
	ToGen         int    `json:"to_generation"`
	HealthPassed  bool   `json:"health_passed"`
	Error         string `json:"error,omitempty"`
}

// Generation represents a NixOS system generation.
type Generation struct {
	Number    int       `json:"number"`
	Date      time.Time `json:"date"`
	Kernel    string    `json:"kernel,omitempty"`
	Configuration string `json:"configuration,omitempty"`
	Active    bool      `json:"active"`
}

// ServiceStatus represents the status of a systemd service.
type ServiceStatus struct {
	Name    string `json:"name"`
	Active  string `json:"active"`
	Running bool   `json:"running"`
	Enabled bool   `json:"enabled"`
	SubState string `json:"sub_state,omitempty"`
	Message string `json:"message,omitempty"`
}

// DriftReport represents the result of a drift detection check.
type DriftReport struct {
	Timestamp         time.Time `json:"timestamp"`
	GitDesiredCommit  string    `json:"git_desired_commit"`
	GitDeployedCommit string    `json:"git_deployed_commit"`
	GitDrift          bool      `json:"git_drift"`
	GenExpected       int       `json:"generation_expected"`
	GenActive         int       `json:"generation_active"`
	GenDrift          bool      `json:"generation_drift"`
	ServicesDrift     bool      `json:"services_drift"`
	DriftedServices   []string  `json:"drifted_services,omitempty"`
	OverallDrift      bool      `json:"overall_drift"`
}

// AuditEntry represents a single audit log entry.
type AuditEntry struct {
	Timestamp    time.Time `json:"timestamp"`
	Actor        string    `json:"actor"`
	Action       string    `json:"action"`
	Target       string    `json:"target"`
	Source       string    `json:"source"`
	Result       string    `json:"result"`
	CommitSHA    string    `json:"commit_sha,omitempty"`
	Generation   int       `json:"generation,omitempty"`
	Error        string    `json:"error,omitempty"`
}

// OverallHealth represents the complete health status of the system.
type OverallHealth struct {
	Timestamp    time.Time              `json:"timestamp"`
	Healthy      bool                   `json:"healthy"`
	Status       string                 `json:"status"`
	Components   map[string]ComponentHealth `json:"components"`
	NixOSGen     int                    `json:"nixos_generation"`
	GitCommit    string                 `json:"git_commit"`
	Uptime       string                 `json:"uptime,omitempty"`
}

// ComponentHealth represents the health of a single system component.
type ComponentHealth struct {
	Name    string `json:"name"`
	Healthy bool   `json:"healthy"`
	Status  string `json:"status"`
	Message string `json:"message,omitempty"`
}

// SystemStatus represents the overall system status.
type SystemStatus struct {
	Timestamp      time.Time `json:"timestamp"`
	Hostname       string    `json:"hostname"`
	NixOSGeneration int      `json:"nixos_generation"`
	GitCommit      string    `json:"git_commit"`
	GitBranch      string    `json:"git_branch"`
	DeployedCommit string    `json:"deployed_commit"`
	Uptime         string    `json:"uptime"`
	KernelVersion  string    `json:"kernel_version"`
	MemoryUsedPct  float64   `json:"memory_used_percent"`
	DiskUsedPct    float64   `json:"disk_used_percent"`
}
