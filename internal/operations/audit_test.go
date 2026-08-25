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

func TestAuditLoggerLogCreatesFile(t *testing.T) {
	dir := t.TempDir()
	logger := &auditLogger{stateDir: dir}

	entry := AuditEntry{
		Timestamp:  time.Date(2026, 8, 24, 10, 30, 0, 0, time.UTC),
		Actor:      "web-ui",
		Action:     "deploy",
		Target:     "abc123",
		Source:     "api",
		Result:     "success",
		CommitSHA:  "abc123",
		Generation: 42,
	}

	err := logger.Log(context.Background(), entry)
	if err != nil {
		t.Fatalf("Log() error: %v", err)
	}

	// Verify file was created
	auditDir := filepath.Join(dir, "audit")
	if _, err := os.Stat(auditDir); os.IsNotExist(err) {
		t.Fatal("audit directory was not created")
	}

	// Find the created file
	files, err := os.ReadDir(auditDir)
	if err != nil {
		t.Fatalf("ReadDir() error: %v", err)
	}
	if len(files) != 1 {
		t.Fatalf("expected 1 audit file, got %d", len(files))
	}

	// Verify file content
	data, err := os.ReadFile(filepath.Join(auditDir, files[0].Name()))
	if err != nil {
		t.Fatalf("ReadFile() error: %v", err)
	}

	var decoded AuditEntry
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal() error: %v", err)
	}

	if decoded.Actor != "web-ui" {
		t.Errorf("Actor = %q, want %q", decoded.Actor, "web-ui")
	}
	if decoded.Action != "deploy" {
		t.Errorf("Action = %q, want %q", decoded.Action, "deploy")
	}
	if decoded.Target != "abc123" {
		t.Errorf("Target = %q, want %q", decoded.Target, "abc123")
	}
	if decoded.Generation != 42 {
		t.Errorf("Generation = %d, want 42", decoded.Generation)
	}
}

func TestAuditLoggerLogSetsTimestamp(t *testing.T) {
	dir := t.TempDir()
	logger := &auditLogger{stateDir: dir}

	entry := AuditEntry{
		Actor:  "operator",
		Action: "rollback",
	}

	before := time.Now()
	err := logger.Log(context.Background(), entry)
	after := time.Now()

	if err != nil {
		t.Fatalf("Log() error: %v", err)
	}

	// Read and verify timestamp was set
	auditDir := filepath.Join(dir, "audit")
	files, err := os.ReadDir(auditDir)
	if err != nil {
		t.Fatalf("ReadDir() error: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(auditDir, files[0].Name()))
	if err != nil {
		t.Fatalf("ReadFile() error: %v", err)
	}

	var decoded AuditEntry
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal() error: %v", err)
	}

	if decoded.Timestamp.Before(before) || decoded.Timestamp.After(after) {
		t.Errorf("timestamp %v not between %v and %v", decoded.Timestamp, before, after)
	}
}

func TestAuditLoggerQueryReturnsLatestFirst(t *testing.T) {
	dir := t.TempDir()
	logger := &auditLogger{stateDir: dir}

	// Create multiple entries with different timestamps
	entries := []AuditEntry{
		{Timestamp: time.Date(2026, 8, 24, 8, 0, 0, 0, time.UTC), Actor: "a1", Action: "deploy"},
		{Timestamp: time.Date(2026, 8, 24, 9, 0, 0, 0, time.UTC), Actor: "a2", Action: "rollback"},
		{Timestamp: time.Date(2026, 8, 24, 10, 0, 0, 0, time.UTC), Actor: "a3", Action: "deploy"},
	}

	for _, e := range entries {
		if err := logger.Log(context.Background(), e); err != nil {
			t.Fatalf("Log() error: %v", err)
		}
	}

	// Query all
	results, err := logger.Query(context.Background(), 10, "")
	if err != nil {
		t.Fatalf("Query() error: %v", err)
	}

	if len(results) != 3 {
		t.Fatalf("expected 3 results, got %d", len(results))
	}

	// Should be sorted by timestamp descending
	if results[0].Actor != "a3" {
		t.Errorf("first result Actor = %q, want %q", results[0].Actor, "a3")
	}
	if results[1].Actor != "a2" {
		t.Errorf("second result Actor = %q, want %q", results[1].Actor, "a2")
	}
	if results[2].Actor != "a1" {
		t.Errorf("third result Actor = %q, want %q", results[2].Actor, "a1")
	}
}

func TestAuditLoggerQueryFiltersByAction(t *testing.T) {
	dir := t.TempDir()
	logger := &auditLogger{stateDir: dir}

	entries := []AuditEntry{
		{Timestamp: time.Date(2026, 8, 24, 8, 0, 0, 0, time.UTC), Actor: "a1", Action: "deploy"},
		{Timestamp: time.Date(2026, 8, 24, 9, 0, 0, 0, time.UTC), Actor: "a2", Action: "rollback"},
		{Timestamp: time.Date(2026, 8, 24, 10, 0, 0, 0, time.UTC), Actor: "a3", Action: "deploy"},
	}

	for _, e := range entries {
		if err := logger.Log(context.Background(), e); err != nil {
			t.Fatalf("Log() error: %v", err)
		}
	}

	// Query with action filter
	results, err := logger.Query(context.Background(), 10, "deploy")
	if err != nil {
		t.Fatalf("Query() error: %v", err)
	}

	if len(results) != 2 {
		t.Fatalf("expected 2 results, got %d", len(results))
	}

	for _, r := range results {
		if r.Action != "deploy" {
			t.Errorf("Action = %q, want %q", r.Action, "deploy")
		}
	}
}

func TestAuditLoggerQueryRespectsLimit(t *testing.T) {
	dir := t.TempDir()
	logger := &auditLogger{stateDir: dir}

	for i := 0; i < 10; i++ {
		entry := AuditEntry{
			Timestamp: time.Date(2026, 8, 24, 8, i, 0, 0, time.UTC),
			Actor:     "operator",
			Action:    "deploy",
		}
		if err := logger.Log(context.Background(), entry); err != nil {
			t.Fatalf("Log() error: %v", err)
		}
	}

	// Query with limit
	results, err := logger.Query(context.Background(), 3, "")
	if err != nil {
		t.Fatalf("Query() error: %v", err)
	}

	if len(results) != 3 {
		t.Fatalf("expected 3 results, got %d", len(results))
	}
}

func TestAuditLoggerQueryHandlesMissingDir(t *testing.T) {
	dir := t.TempDir()
	logger := &auditLogger{stateDir: dir}

	// Query non-existent directory should return nil, nil
	results, err := logger.Query(context.Background(), 10, "")
	if err != nil {
		t.Fatalf("Query() error: %v", err)
	}
	if results != nil {
		t.Errorf("expected nil results, got %v", results)
	}
}

func TestAuditLoggerQueryHandlesCorruptFiles(t *testing.T) {
	dir := t.TempDir()
	logger := &auditLogger{stateDir: dir}

	// Create audit directory with corrupt file
	auditDir := filepath.Join(dir, "audit")
	if err := os.MkdirAll(auditDir, 0755); err != nil {
		t.Fatalf("MkdirAll() error: %v", err)
	}

	corruptFile := filepath.Join(auditDir, "corrupt.json")
	if err := os.WriteFile(corruptFile, []byte("not valid json"), 0644); err != nil {
		t.Fatalf("WriteFile() error: %v", err)
	}

	// Add a valid entry
	entry := AuditEntry{
		Timestamp: time.Now(),
		Actor:     "operator",
		Action:    "deploy",
	}
	if err := logger.Log(context.Background(), entry); err != nil {
		t.Fatalf("Log() error: %v", err)
	}

	// Query should skip corrupt files
	results, err := logger.Query(context.Background(), 10, "")
	if err != nil {
		t.Fatalf("Query() error: %v", err)
	}

	if len(results) != 1 {
		t.Fatalf("expected 1 result (corrupt file skipped), got %d", len(results))
	}
}

func TestCleanAuditLogs(t *testing.T) {
	dir := t.TempDir()
	auditDir := filepath.Join(dir, "audit")
	if err := os.MkdirAll(auditDir, 0755); err != nil {
		t.Fatalf("MkdirAll() error: %v", err)
	}

	// Create old files (30 days old)
	oldTime := time.Now().AddDate(0, 0, -30)
	for i := 0; i < 5; i++ {
		oldFile := filepath.Join(auditDir, oldTime.Format("20060102-150405")+"-deploy.json")
		_ = os.WriteFile(oldFile, []byte("{}"), 0644)
		_ = os.Chtimes(oldFile, oldTime, oldTime)
	}

	// Create recent files
	recentTime := time.Now()
	for i := 0; i < 3; i++ {
		recentFile := filepath.Join(auditDir, recentTime.Format("20060102-150405")+"-rollback.json")
		_ = os.WriteFile(recentFile, []byte("{}"), 0644)
	}

	// Clean old logs (keep 7 days)
	CleanAuditLogs(dir, 7)

	// Verify only recent files remain
	files, err := os.ReadDir(auditDir)
	if err != nil {
		t.Fatalf("ReadDir() error: %v", err)
	}

	// All old files should be removed
	for _, f := range files {
		info, err := f.Info()
		if err != nil {
			continue
		}
		if info.ModTime().Before(time.Now().AddDate(0, 0, -7)) {
			t.Errorf("old file %s should have been removed", f.Name())
		}
	}
}

func TestCleanHistoryRemovesOldEntries(t *testing.T) {
	dir := t.TempDir()

	// Create 60 entries with unique filenames
	for i := 0; i < 60; i++ {
		filename := filepath.Join(dir, fmt.Sprintf("20260824-1030%02d00-prague.json", i))
		_ = os.WriteFile(filename, []byte("{}"), 0644)
	}

	cleanHistory(dir, 50)

	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("ReadDir() error: %v", err)
	}

	if len(entries) != 50 {
		t.Errorf("expected 50 entries after cleanup, got %d", len(entries))
	}
}
