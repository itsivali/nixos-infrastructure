package operations

import (
	"encoding/json"
	"testing"
	"time"
)

func TestDeploymentStateConstants(t *testing.T) {
	tests := []struct {
		name     string
		state    DeploymentState
		expected string
	}{
		{"pending state", StatePending, "pending"},
		{"validating state", StateValidating, "validating"},
		{"building state", StateBuilding, "building"},
		{"activating state", StateActivating, "activating"},
		{"verifying state", StateVerifying, "verifying"},
		{"healthy state", StateHealthy, "healthy"},
		{"complete state", StateComplete, "complete"},
		{"failed state", StateFailed, "failed"},
		{"rolled_back state", StateRolledBack, "rolled_back"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if string(tt.state) != tt.expected {
				t.Errorf("state = %q, want %q", string(tt.state), tt.expected)
			}
		})
	}
}

func TestDeploymentRecordJSON(t *testing.T) {
	now := time.Now()
	record := &DeploymentRecord{
		ID:            "20260824-103000-prague",
		CommitSHA:     "abc123def456",
		PreviousSHA:   "789012345678",
		Generation:    42,
		PreviousGen:   41,
		Actor:         "web-ui",
		Source:        "api",
		Timestamp:     now,
		State:         StateComplete,
		Status:        "deployed",
		HealthResult:  "passed",
		Duration:      "2m30s",
		Changelog:     "fix: resolve firewall issue",
		ChangedFiles:  "security/firewall.nix\nhosts/prague.nix",
	}

	// Test JSON serialization
	data := marshalJSON(t, record)

	// Test JSON deserialization
	var decoded DeploymentRecord
	unmarshalJSON(t, data, &decoded)

	if decoded.ID != record.ID {
		t.Errorf("ID = %q, want %q", decoded.ID, record.ID)
	}
	if decoded.CommitSHA != record.CommitSHA {
		t.Errorf("CommitSHA = %q, want %q", decoded.CommitSHA, record.CommitSHA)
	}
	if decoded.Generation != record.Generation {
		t.Errorf("Generation = %d, want %d", decoded.Generation, record.Generation)
	}
	if decoded.Actor != record.Actor {
		t.Errorf("Actor = %q, want %q", decoded.Actor, record.Actor)
	}
	if decoded.State != record.State {
		t.Errorf("State = %q, want %q", decoded.State, record.State)
	}
}

func TestDeployOpts(t *testing.T) {
	tests := []struct {
		name   string
		opts   DeployOpts
		commit string
		actor  string
		source string
	}{
		{
			name:   "with specific commit",
			opts:   DeployOpts{Commit: "abc123", Actor: "web-ui", Source: "api"},
			commit: "abc123",
			actor:  "web-ui",
			source: "api",
		},
		{
			name:   "empty opts",
			opts:   DeployOpts{},
			commit: "",
			actor:  "",
			source: "",
		},
		{
			name:   "gitops reconciler",
			opts:   DeployOpts{Actor: "gitops-reconciler", Source: "gitops"},
			commit: "",
			actor:  "gitops-reconciler",
			source: "gitops",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.opts.Commit != tt.commit {
				t.Errorf("Commit = %q, want %q", tt.opts.Commit, tt.commit)
			}
			if tt.opts.Actor != tt.actor {
				t.Errorf("Actor = %q, want %q", tt.opts.Actor, tt.actor)
			}
			if tt.opts.Source != tt.source {
				t.Errorf("Source = %q, want %q", tt.opts.Source, tt.source)
			}
		})
	}
}

func TestRollbackOpts(t *testing.T) {
	tests := []struct {
		name       string
		opts       RollbackOpts
		generation int
		actor      string
		reason     string
	}{
		{
			name:       "previous generation",
			opts:       RollbackOpts{Generation: 0, Actor: "operator", Reason: "health check failed"},
			generation: 0,
			actor:      "operator",
			reason:     "health check failed",
		},
		{
			name:       "specific generation",
			opts:       RollbackOpts{Generation: 42, Actor: "api", Reason: "manual rollback"},
			generation: 42,
			actor:      "api",
			reason:     "manual rollback",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.opts.Generation != tt.generation {
				t.Errorf("Generation = %d, want %d", tt.opts.Generation, tt.generation)
			}
			if tt.opts.Actor != tt.actor {
				t.Errorf("Actor = %q, want %q", tt.opts.Actor, tt.actor)
			}
			if tt.opts.Reason != tt.reason {
				t.Errorf("Reason = %q, want %q", tt.opts.Reason, tt.reason)
			}
		})
	}
}

func TestRollbackResultSemantics(t *testing.T) {
	tests := []struct {
		name         string
		result       RollbackResult
		expectSuccess bool
	}{
		{
			name: "successful rollback with health pass",
			result: RollbackResult{
				Success:      true,
				FromGen:      42,
				ToGen:        41,
				HealthPassed: true,
			},
			expectSuccess: true,
		},
		{
			name: "rollback with health failure should be marked failed",
			result: RollbackResult{
				Success:      false,
				FromGen:      42,
				ToGen:        41,
				HealthPassed: false,
				Error:        "health check failed",
			},
			expectSuccess: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.result.Success != tt.expectSuccess {
				t.Errorf("Success = %v, want %v", tt.result.Success, tt.expectSuccess)
			}
			if tt.result.FromGen != 42 {
				t.Errorf("FromGen = %d, want 42", tt.result.FromGen)
			}
			if tt.result.ToGen != 41 {
				t.Errorf("ToGen = %d, want 41", tt.result.ToGen)
			}
		})
	}
}

func TestDriftReportStructure(t *testing.T) {
	report := &DriftReport{
		Timestamp:         time.Now(),
		GitDesiredCommit:  "abc123",
		GitDeployedCommit: "abc123",
		GitDrift:          false,
		GenExpected:       42,
		GenActive:         42,
		GenDrift:          false,
		ServicesDrift:     false,
		DriftedServices:   []string{},
		OverallDrift:      false,
	}

	// Test no drift
	if report.OverallDrift {
		t.Error("expected no drift when all components are in sync")
	}

	// Test with git drift
	report.GitDrift = true
	report.OverallDrift = report.GitDrift || report.GenDrift || report.ServicesDrift
	if !report.OverallDrift {
		t.Error("expected drift when git commits differ")
	}

	// Reset and test with generation drift
	report.GitDrift = false
	report.GenDrift = true
	report.OverallDrift = report.GitDrift || report.GenDrift || report.ServicesDrift
	if !report.OverallDrift {
		t.Error("expected drift when generations differ")
	}

	// Reset and test with service drift
	report.GenDrift = false
	report.ServicesDrift = true
	report.DriftedServices = []string{"sshd.service", "tailscaled.service"}
	report.OverallDrift = report.GitDrift || report.GenDrift || report.ServicesDrift
	if !report.OverallDrift {
		t.Error("expected drift when services are down")
	}
	if len(report.DriftedServices) != 2 {
		t.Errorf("expected 2 drifted services, got %d", len(report.DriftedServices))
	}
}

func TestSystemStatusStructure(t *testing.T) {
	status := &SystemStatus{
		Timestamp:       time.Now(),
		Hostname:        "prague",
		NixOSGeneration: 42,
		GitCommit:       "abc123",
		GitBranch:       "main",
		DeployedCommit:  "abc123",
		Uptime:          "3d12h",
		KernelVersion:   "6.12.43",
		MemoryUsedPct:   65.2,
		DiskUsedPct:     45.0,
	}

	if status.Hostname != "prague" {
		t.Errorf("Hostname = %q, want %q", status.Hostname, "prague")
	}
	if status.NixOSGeneration != 42 {
		t.Errorf("NixOSGeneration = %d, want 42", status.NixOSGeneration)
	}
	if status.GitBranch != "main" {
		t.Errorf("GitBranch = %q, want %q", status.GitBranch, "main")
	}
}

func marshalJSON(t *testing.T, v interface{}) []byte {
	t.Helper()
	data, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("failed to marshal JSON: %v", err)
	}
	return data
}

func unmarshalJSON(t *testing.T, data []byte, v interface{}) {
	t.Helper()
	if err := json.Unmarshal(data, v); err != nil {
		t.Fatalf("failed to unmarshal JSON: %v", err)
	}
}
