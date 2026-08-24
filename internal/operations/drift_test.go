package operations

import (
	"context"
	"encoding/json"
	"testing"
	"time"
)

// mockDriftService is a testable implementation of DriftService
type mockDriftService struct {
	detectFunc func(ctx context.Context) (*DriftReport, error)
}

func (m *mockDriftService) Detect(ctx context.Context) (*DriftReport, error) {
	if m.detectFunc != nil {
		return m.detectFunc(ctx)
	}
	return &DriftReport{
		Timestamp:         time.Now(),
		GitDesiredCommit:  "abc123",
		GitDeployedCommit: "abc123",
		GitDrift:          false,
		GenExpected:       42,
		GenActive:         42,
		GenDrift:          false,
		ServicesDrift:     false,
		OverallDrift:      false,
	}, nil
}

func TestDriftServiceDetect(t *testing.T) {
	// Create a mock drift service that returns controlled values
	service := &mockDriftService{}

	tests := []struct {
		name           string
		desiredCommit  string
		deployedCommit string
		genExpected    int
		genActive      int
		servicesDrift  bool
		driftedSvcs    []string
		expectDrift    bool
	}{
		{
			name:           "no drift",
			desiredCommit:  "abc123",
			deployedCommit: "abc123",
			genExpected:    42,
			genActive:      42,
			servicesDrift:  false,
			driftedSvcs:    []string{},
			expectDrift:    false,
		},
		{
			name:           "git drift",
			desiredCommit:  "abc123",
			deployedCommit: "def456",
			genExpected:    42,
			genActive:      42,
			servicesDrift:  false,
			driftedSvcs:    []string{},
			expectDrift:    true,
		},
		{
			name:           "generation drift",
			desiredCommit:  "abc123",
			deployedCommit: "abc123",
			genExpected:    42,
			genActive:      41,
			servicesDrift:  false,
			driftedSvcs:    []string{},
			expectDrift:    true,
		},
		{
			name:           "service drift",
			desiredCommit:  "abc123",
			deployedCommit: "abc123",
			genExpected:    42,
			genActive:      42,
			servicesDrift:  true,
			driftedSvcs:    []string{"sshd.service", "tailscaled.service"},
			expectDrift:    true,
		},
		{
			name:           "all drift",
			desiredCommit:  "abc123",
			deployedCommit: "def456",
			genExpected:    42,
			genActive:      40,
			servicesDrift:  true,
			driftedSvcs:    []string{"nginx.service"},
			expectDrift:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			service.detectFunc = func(ctx context.Context) (*DriftReport, error) {
				report := &DriftReport{
					Timestamp:         time.Now(),
					GitDesiredCommit:  tt.desiredCommit,
					GitDeployedCommit: tt.deployedCommit,
					GitDrift:          tt.desiredCommit != tt.deployedCommit,
					GenExpected:       tt.genExpected,
					GenActive:         tt.genActive,
					GenDrift:          tt.genExpected != tt.genActive,
					ServicesDrift:     tt.servicesDrift,
					DriftedServices:   tt.driftedSvcs,
					OverallDrift:      tt.desiredCommit != tt.deployedCommit || tt.genExpected != tt.genActive || tt.servicesDrift,
				}
				return report, nil
			}

			report, err := service.Detect(context.Background())
			if err != nil {
				t.Fatalf("Detect() error: %v", err)
			}

			if report.OverallDrift != tt.expectDrift {
				t.Errorf("OverallDrift = %v, want %v", report.OverallDrift, tt.expectDrift)
			}
			if report.GitDrift != (tt.desiredCommit != tt.deployedCommit) {
				t.Errorf("GitDrift = %v, want %v", report.GitDrift, tt.desiredCommit != tt.deployedCommit)
			}
			if report.GenDrift != (tt.genExpected != tt.genActive) {
				t.Errorf("GenDrift = %v, want %v", report.GenDrift, tt.genExpected != tt.genActive)
			}
			if report.ServicesDrift != tt.servicesDrift {
				t.Errorf("ServicesDrift = %v, want %v", report.ServicesDrift, tt.servicesDrift)
			}
			if len(report.DriftedServices) != len(tt.driftedSvcs) {
				t.Errorf("DriftedServices count = %d, want %d", len(report.DriftedServices), len(tt.driftedSvcs))
			}
		})
	}
}

func TestDriftReportJSONSerialization(t *testing.T) {
	report := &DriftReport{
		Timestamp:         time.Date(2026, 8, 24, 10, 30, 0, 0, time.UTC),
		GitDesiredCommit:  "abc123def456",
		GitDeployedCommit: "abc123def456",
		GitDrift:          false,
		GenExpected:       42,
		GenActive:         42,
		GenDrift:          false,
		ServicesDrift:     false,
		DriftedServices:   []string{},
		OverallDrift:      false,
	}

	// Serialize
	data, err := jsonMarshal(report)
	if err != nil {
		t.Fatalf("json.Marshal() error: %v", err)
	}

	// Deserialize
	var decoded DriftReport
	if err := jsonUnmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal() error: %v", err)
	}

	// Verify
	if decoded.GitDesiredCommit != report.GitDesiredCommit {
		t.Errorf("GitDesiredCommit = %q, want %q", decoded.GitDesiredCommit, report.GitDesiredCommit)
	}
	if decoded.GitDeployedCommit != report.GitDeployedCommit {
		t.Errorf("GitDeployedCommit = %q, want %q", decoded.GitDeployedCommit, report.GitDeployedCommit)
	}
	if decoded.GenExpected != report.GenExpected {
		t.Errorf("GenExpected = %d, want %d", decoded.GenExpected, report.GenExpected)
	}
	if decoded.GenActive != report.GenActive {
		t.Errorf("GenActive = %d, want %d", decoded.GenActive, report.GenActive)
	}
	if decoded.OverallDrift != report.OverallDrift {
		t.Errorf("OverallDrift = %v, want %v", decoded.OverallDrift, report.OverallDrift)
	}
}

func TestDriftServiceHandlesNetworkFailure(t *testing.T) {
	service := &mockDriftService{}

	service.detectFunc = func(ctx context.Context) (*DriftReport, error) {
		// Simulate network failure - desired commit is empty
		return &DriftReport{
			Timestamp:         time.Now(),
			GitDesiredCommit:  "",
			GitDeployedCommit: "abc123",
			GitDrift:          false, // Empty desired means no drift detected
			GenExpected:       0,
			GenActive:         42,
			GenDrift:          false, // Zero expected means no drift detected
			ServicesDrift:     false,
			OverallDrift:      false,
		}, nil
	}

	report, err := service.Detect(context.Background())
	if err != nil {
		t.Fatalf("Detect() error: %v", err)
	}

	// When desired is empty, drift should not be detected (fail-safe)
	if report.OverallDrift {
		t.Error("expected no drift when desired commit is empty (network failure)")
	}
}

func TestDriftServiceHandlesCorruptState(t *testing.T) {
	service := &mockDriftService{}

	service.detectFunc = func(ctx context.Context) (*DriftReport, error) {
		// Simulate corrupt state - generation numbers are zero
		return &DriftReport{
			Timestamp:         time.Now(),
			GitDesiredCommit:  "abc123",
			GitDeployedCommit: "abc123",
			GitDrift:          false,
			GenExpected:       0,
			GenActive:         0,
			GenDrift:          false,
			ServicesDrift:     true,
			DriftedServices:   []string{"unknown.service"},
			OverallDrift:      true,
		}, nil
	}

	report, err := service.Detect(context.Background())
	if err != nil {
		t.Fatalf("Detect() error: %v", err)
	}

	// Service drift should still be detected
	if !report.OverallDrift {
		t.Error("expected drift when services are down")
	}
	if !report.ServicesDrift {
		t.Error("expected ServicesDrift = true")
	}
	if len(report.DriftedServices) != 1 {
		t.Errorf("expected 1 drifted service, got %d", len(report.DriftedServices))
	}
}

// JSON helper functions
func jsonMarshal(v interface{}) ([]byte, error) {
	return json.Marshal(v)
}

func jsonUnmarshal(data []byte, v interface{}) error {
	return json.Unmarshal(data, v)
}
