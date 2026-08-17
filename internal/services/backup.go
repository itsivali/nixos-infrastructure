package services

import (
	"context"
	"time"
)

// BackupService defines the interface for backup operations.
// This extracts backup methods from GitOpsService into a dedicated domain.
type BackupService interface {
	// Trigger initiates a new backup operation.
	Trigger(ctx context.Context) error

	// Status returns the current backup service status.
	Status(ctx context.Context) (*BackupStatus, error)

	// ListSnapshots returns recent backup snapshots.
	ListSnapshots(ctx context.Context, limit int) ([]Snapshot, error)

	// LastSnapshot returns the most recent backup snapshot.
	LastSnapshot(ctx context.Context) (*Snapshot, error)

	// LastRun returns the timestamp of the last backup execution.
	LastRun(ctx context.Context) (time.Time, error)
}

// BackupStatus represents the current state of the backup service.
type BackupStatus struct {
	Active    bool
	Message   string
	LastRun   time.Time
	NextRun   time.Time
	Snapshots int
}

// Snapshot represents a single backup snapshot.
type Snapshot struct {
	ID       string
	Time     time.Time
	Hostname string
	Paths    []string
	Size     int64
}
