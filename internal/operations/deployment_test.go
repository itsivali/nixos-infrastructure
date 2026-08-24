package operations

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// mockDeploymentService is a testable implementation of DeploymentService
type mockDeploymentService struct {
	repoDir    string
	stateDir   string
	audit      AuditLogger
	mu         chan struct{}
	deployFunc func(ctx context.Context, opts DeployOpts) (*DeploymentRecord, error)
	statusFunc func(ctx context.Context) (*DeploymentRecord, error)
}

func newMockDeploymentService(t *testing.T) *mockDeploymentService {
	t.Helper()
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	audit := &auditLogger{stateDir: stateDir}
	return &mockDeploymentService{
		repoDir:  dir,
		stateDir: stateDir,
		audit:    audit,
		mu:       make(chan struct{}, 1),
	}
}

func (m *mockDeploymentService) Deploy(ctx context.Context, opts DeployOpts) (*DeploymentRecord, error) {
	if m.deployFunc != nil {
		return m.deployFunc(ctx, opts)
	}
	record := &DeploymentRecord{
		ID:        "test-deploy-1",
		CommitSHA: "abc123",
		Actor:     opts.Actor,
		Source:    opts.Source,
		Timestamp: time.Now(),
		State:     StateComplete,
		Status:    "deployed",
	}
	return record, nil
}

func (m *mockDeploymentService) Rollback(ctx context.Context, opts RollbackOpts) (*RollbackResult, error) {
	return &RollbackResult{
		Success:      true,
		FromGen:      42,
		ToGen:        41,
		HealthPassed: true,
	}, nil
}

func (m *mockDeploymentService) Status(ctx context.Context) (*DeploymentRecord, error) {
	if m.statusFunc != nil {
		return m.statusFunc(ctx)
	}
	return &DeploymentRecord{
		Generation: 42,
		CommitSHA:  "abc123",
		State:      StateComplete,
		Status:     "no deployment record",
		Timestamp:  time.Now(),
	}, nil
}

func (m *mockDeploymentService) History(ctx context.Context, limit int) ([]DeploymentRecord, error) {
	return []DeploymentRecord{
		{ID: "deploy-1", CommitSHA: "abc123", State: StateComplete},
		{ID: "deploy-2", CommitSHA: "def456", State: StateComplete},
	}, nil
}

func (m *mockDeploymentService) AcquireLock(ctx context.Context) (func(), error) {
	return func() {}, nil
}

func TestMockDeploymentDeploySuccess(t *testing.T) {
	mock := newMockDeploymentService(t)

	record, err := mock.Deploy(context.Background(), DeployOpts{
		Commit: "abc123",
		Actor:  "web-ui",
		Source: "api",
	})

	if err != nil {
		t.Fatalf("Deploy() error: %v", err)
	}

	if record.ID != "test-deploy-1" {
		t.Errorf("ID = %q, want %q", record.ID, "test-deploy-1")
	}
	if record.CommitSHA != "abc123" {
		t.Errorf("CommitSHA = %q, want %q", record.CommitSHA, "abc123")
	}
	if record.Actor != "web-ui" {
		t.Errorf("Actor = %q, want %q", record.Actor, "web-ui")
	}
	if record.State != StateComplete {
		t.Errorf("State = %q, want %q", record.State, StateComplete)
	}
}

func TestMockDeploymentRollbackSuccess(t *testing.T) {
	mock := newMockDeploymentService(t)

	result, err := mock.Rollback(context.Background(), RollbackOpts{
		Generation: 0,
		Actor:      "operator",
		Reason:     "health check failed",
	})

	if err != nil {
		t.Fatalf("Rollback() error: %v", err)
	}

	if !result.Success {
		t.Error("expected Success = true")
	}
	if result.FromGen != 42 {
		t.Errorf("FromGen = %d, want 42", result.FromGen)
	}
	if result.ToGen != 41 {
		t.Errorf("ToGen = %d, want 41", result.ToGen)
	}
	if !result.HealthPassed {
		t.Error("expected HealthPassed = true")
	}
}

func TestMockDeploymentStatus(t *testing.T) {
	mock := newMockDeploymentService(t)

	status, err := mock.Status(context.Background())
	if err != nil {
		t.Fatalf("Status() error: %v", err)
	}

	if status.Generation != 42 {
		t.Errorf("Generation = %d, want 42", status.Generation)
	}
	if status.CommitSHA != "abc123" {
		t.Errorf("CommitSHA = %q, want %q", status.CommitSHA, "abc123")
	}
}

func TestMockDeploymentHistory(t *testing.T) {
	mock := newMockDeploymentService(t)

	history, err := mock.History(context.Background(), 10)
	if err != nil {
		t.Fatalf("History() error: %v", err)
	}

	if len(history) != 2 {
		t.Fatalf("expected 2 history entries, got %d", len(history))
	}
	if history[0].ID != "deploy-1" {
		t.Errorf("history[0].ID = %q, want %q", history[0].ID, "deploy-1")
	}
}

func TestDeploymentServiceSaveAndLoadState(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		t.Fatalf("MkdirAll() error: %v", err)
	}

	record := &DeploymentRecord{
		ID:        "test-20260824-103000-prague",
		CommitSHA: "abc123def456",
		Actor:     "web-ui",
		Source:    "api",
		Timestamp: time.Date(2026, 8, 24, 10, 30, 0, 0, time.UTC),
		State:     StateComplete,
		Status:    "deployed",
		Generation: 42,
	}

	// Save state
	data, err := json.MarshalIndent(record, "", "  ")
	if err != nil {
		t.Fatalf("MarshalIndent() error: %v", err)
	}

	statePath := filepath.Join(stateDir, "last-deploy.json")
	if err := os.WriteFile(statePath, data, 0644); err != nil {
		t.Fatalf("WriteFile() error: %v", err)
	}

	// Load state
	loadedData, err := os.ReadFile(statePath)
	if err != nil {
		t.Fatalf("ReadFile() error: %v", err)
	}

	var loaded DeploymentRecord
	if err := json.Unmarshal(loadedData, &loaded); err != nil {
		t.Fatalf("Unmarshal() error: %v", err)
	}

	if loaded.ID != record.ID {
		t.Errorf("ID = %q, want %q", loaded.ID, record.ID)
	}
	if loaded.CommitSHA != record.CommitSHA {
		t.Errorf("CommitSHA = %q, want %q", loaded.CommitSHA, record.CommitSHA)
	}
	if loaded.Generation != record.Generation {
		t.Errorf("Generation = %d, want %d", loaded.Generation, record.Generation)
	}
}

func TestDeploymentServiceHistoryFiles(t *testing.T) {
	dir := t.TempDir()
	historyDir := filepath.Join(dir, "state", "history")
	if err := os.MkdirAll(historyDir, 0755); err != nil {
		t.Fatalf("MkdirAll() error: %v", err)
	}

	// Create multiple history entries
	records := []DeploymentRecord{
		{ID: "deploy-1", CommitSHA: "aaa", State: StateComplete, Generation: 40},
		{ID: "deploy-2", CommitSHA: "bbb", State: StateComplete, Generation: 41},
		{ID: "deploy-3", CommitSHA: "ccc", State: StateFailed, Generation: 42},
	}

	for _, r := range records {
		data, err := json.Marshal(r)
		if err != nil {
			t.Fatalf("Marshal() error: %v", err)
		}
		path := filepath.Join(historyDir, r.ID+".json")
		if err := os.WriteFile(path, data, 0644); err != nil {
			t.Fatalf("WriteFile() error: %v", err)
		}
	}

	// Read all entries
	entries, err := os.ReadDir(historyDir)
	if err != nil {
		t.Fatalf("ReadDir() error: %v", err)
	}

	if len(entries) != 3 {
		t.Fatalf("expected 3 history entries, got %d", len(entries))
	}

	// Read and verify each entry
	for _, entry := range entries {
		data, err := os.ReadFile(filepath.Join(historyDir, entry.Name()))
		if err != nil {
			t.Fatalf("ReadFile() error: %v", err)
		}

		var record DeploymentRecord
		if err := json.Unmarshal(data, &record); err != nil {
			t.Fatalf("Unmarshal() error: %v", err)
		}

		if record.ID == "" {
			t.Errorf("empty ID in history entry %s", entry.Name())
		}
	}
}

func TestDeploymentServiceLockConcurrency(t *testing.T) {
	dir := t.TempDir()
	lockPath := filepath.Join(dir, "deploy.lock")

	// Acquire first lock
	fd1, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0660)
	if err != nil {
		t.Fatalf("OpenFile() error: %v", err)
	}
	defer fd1.Close()

	if err := syscallFlock(fd1); err != nil {
		t.Fatalf("flock() error: %v", err)
	}

	// Second lock should fail (non-blocking)
	fd2, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0660)
	if err != nil {
		t.Fatalf("OpenFile() error: %v", err)
	}
	defer fd2.Close()

	err = syscallFlock(fd2)
	if err == nil {
		t.Error("expected flock to fail when lock is held")
		syscallFlockUnlock(fd2)
	}

	// Release first lock
	syscallFlockUnlock(fd1)

	// Now second lock should succeed
	if err := syscallFlock(fd2); err != nil {
		t.Errorf("expected flock to succeed after release: %v", err)
	}
	syscallFlockUnlock(fd2)
}

func TestDeploymentServiceCustomDeployBehavior(t *testing.T) {
	mock := newMockDeploymentService(t)

	// Custom deploy function that returns an error
	mock.deployFunc = func(ctx context.Context, opts DeployOpts) (*DeploymentRecord, error) {
		return nil, os.ErrNotExist
	}

	_, err := mock.Deploy(context.Background(), DeployOpts{})
	if err == nil {
		t.Error("expected error from custom deploy function")
	}

	// Custom deploy function that returns a custom record
	mock.deployFunc = func(ctx context.Context, opts DeployOpts) (*DeploymentRecord, error) {
		return &DeploymentRecord{
			ID:        "custom-deploy",
			CommitSHA: opts.Commit,
			State:     StateFailed,
			Error:     "build failed",
		}, nil
	}

	record, err := mock.Deploy(context.Background(), DeployOpts{Commit: "failed-sha"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if record.State != StateFailed {
		t.Errorf("State = %q, want %q", record.State, StateFailed)
	}
	if record.Error != "build failed" {
		t.Errorf("Error = %q, want %q", record.Error, "build failed")
	}
}

func TestCleanHistoryPreservesEntries(t *testing.T) {
	dir := t.TempDir()

	// Create 45 entries with unique filenames (under limit of 50)
	for i := 0; i < 45; i++ {
		filename := filepath.Join(dir, fmt.Sprintf("20260824-1030%02d00-prague.json", i))
		os.WriteFile(filename, []byte("{}"), 0644)
	}

	cleanHistory(dir, 50)

	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("ReadDir() error: %v", err)
	}

	if len(entries) != 45 {
		t.Errorf("expected 45 entries to be preserved, got %d", len(entries))
	}
}

func TestCleanHistoryHandlesMissingDir(t *testing.T) {
	// Should not panic with missing directory
	cleanHistory("/nonexistent/path", 50)
}
