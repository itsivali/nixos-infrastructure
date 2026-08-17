package impl

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/services"
)

// ResticBackup implements services.BackupService by driving restic and
// systemctl via shell commands. It replaces the backup methods that lived
// inside TelegramServices.GitOpsService.
type ResticBackup struct{}

// NewResticBackup creates a backup service that drives restic via systemctl.
func NewResticBackup() *ResticBackup {
	return &ResticBackup{}
}

func (r *ResticBackup) Trigger(ctx context.Context) error {
	cmd := exec.CommandContext(ctx, "systemctl", "start", "restic-backup.service")
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("restic-backup start failed: %w: %s", err, string(out))
	}
	return nil
}

func (r *ResticBackup) Status(ctx context.Context) (*services.BackupStatus, error) {
	timerOut, err := exec.CommandContext(ctx, "systemctl", "show", "restic-backup.timer",
		"--property=ActiveState,NextElapseUSecRealtime").CombinedOutput()
	if err != nil {
		return &services.BackupStatus{Active: false, Message: "timer not found"}, nil
	}

	status := &services.BackupStatus{}
	lines := strings.Split(string(timerOut), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "ActiveState=") {
			status.Active = strings.TrimPrefix(line, "ActiveState=") == "active"
		}
		if strings.HasPrefix(line, "NextElapseUSecRealtime=") {
			val := strings.TrimPrefix(line, "NextElapseUSecRealtime=")
			if t, err := time.Parse("Mon 2006-01-02 15:04:05 MST", val); err == nil {
				status.NextRun = t
			}
		}
	}

	lastRun, err := r.LastRun(ctx)
	if err == nil {
		status.LastRun = lastRun
	}

	snapshots, err := r.ListSnapshots(ctx, 100)
	if err == nil {
		status.Snapshots = len(snapshots)
	}

	status.Message = "ok"
	return status, nil
}

func (r *ResticBackup) ListSnapshots(ctx context.Context, limit int) ([]services.Snapshot, error) {
	cmd := exec.CommandContext(ctx, "restic", "snapshots", "--latest", strconv.Itoa(limit), "--json")
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("restic snapshots failed: %w", err)
	}

	// Parse JSON array of snapshots
	var raw []struct {
		ID       string                  `json:"id"`
		Time     string                  `json:"time"`
		Tree     string                  `json:"tree"`
		Paths    []struct{ Path string } `json:"paths"`
		Hostname string                  `json:"hostname"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		return nil, fmt.Errorf("parse snapshots: %w", err)
	}

	snapshots := make([]services.Snapshot, 0, len(raw))
	for _, s := range raw {
		sn := services.Snapshot{ID: s.ID, Hostname: s.Hostname}
		if t, err := time.Parse(time.RFC3339, s.Time); err == nil {
			sn.Time = t
		}
		for _, p := range s.Paths {
			sn.Paths = append(sn.Paths, p.Path)
		}
		snapshots = append(snapshots, sn)
	}
	return snapshots, nil
}

func (r *ResticBackup) LastSnapshot(ctx context.Context) (*services.Snapshot, error) {
	snaps, err := r.ListSnapshots(ctx, 1)
	if err != nil {
		return nil, err
	}
	if len(snaps) == 0 {
		return nil, fmt.Errorf("no snapshots found")
	}
	return &snaps[0], nil
}

func (r *ResticBackup) LastRun(ctx context.Context) (time.Time, error) {
	cmd := exec.CommandContext(ctx, "systemctl", "show", "restic-backup.service",
		"--property=ExecMainStartTimestamp")
	out, err := cmd.Output()
	if err != nil {
		return time.Time{}, fmt.Errorf("restic status: %w", err)
	}

	val := strings.TrimSpace(strings.TrimPrefix(string(out), "ExecMainStartTimestamp="))
	if val == "" || val == "n/a" {
		return time.Time{}, nil
	}
	return time.Parse("Mon 2006-01-02 15:04:05 MST", val)
}
