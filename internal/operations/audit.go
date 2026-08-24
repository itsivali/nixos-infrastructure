package operations

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// auditLogger implements AuditLogger.
type auditLogger struct {
	stateDir string
}

// NewAuditLogger creates an audit logger that persists to disk.
func NewAuditLogger() *auditLogger {
	return &auditLogger{
		stateDir: "/var/lib/deployment",
	}
}

func (a *auditLogger) Log(ctx context.Context, entry AuditEntry) error {
	if entry.Timestamp.IsZero() {
		entry.Timestamp = time.Now()
	}

	dir := filepath.Join(a.stateDir, "audit")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("create audit dir: %w", err)
	}

	// Generate filename from timestamp
	filename := fmt.Sprintf("%s-%s.json",
		entry.Timestamp.Format("20060102-150405"),
		entry.Action)

	data, err := json.MarshalIndent(entry, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal audit entry: %w", err)
	}

	path := filepath.Join(dir, filename)
	if err := os.WriteFile(path, data, 0644); err != nil {
		return fmt.Errorf("write audit entry: %w", err)
	}

	return nil
}

func (a *auditLogger) Query(ctx context.Context, limit int, action string) ([]AuditEntry, error) {
	dir := filepath.Join(a.stateDir, "audit")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, nil
	}

	var results []AuditEntry
	for i := len(entries) - 1; i >= 0 && len(results) < limit; i-- {
		if entries[i].IsDir() {
			continue
		}

		data, err := os.ReadFile(filepath.Join(dir, entries[i].Name()))
		if err != nil {
			continue
		}

		var entry AuditEntry
		if err := json.Unmarshal(data, &entry); err != nil {
			continue
		}

		if action != "" && entry.Action != action {
			continue
		}

		results = append(results, entry)
	}

	// Sort by timestamp descending
	sort.Slice(results, func(i, j int) bool {
		return results[i].Timestamp.After(results[j].Timestamp)
	})

	return results, nil
}

// cleanAuditLogs removes old audit logs (keep last N days).
func CleanAuditLogs(stateDir string, maxDays int) {
	dir := filepath.Join(stateDir, "audit")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}

	cutoff := time.Now().AddDate(0, 0, -maxDays)
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		info, err := entry.Info()
		if err != nil {
			continue
		}

		if info.ModTime().Before(cutoff) {
			os.Remove(filepath.Join(dir, entry.Name()))
		}
	}
}

// unused but available for future use
func parseDeploymentID(filename string) string {
	return strings.TrimSuffix(filename, ".json")
}
