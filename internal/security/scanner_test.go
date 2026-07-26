package security

import (
	"testing"
	"time"
)

func TestRunFullScan(t *testing.T) {
	result, err := RunFullScan()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result == nil {
		t.Fatal("expected result")
	}

	if result.Timestamp.IsZero() {
		t.Error("expected non-zero timestamp")
	}

	if result.MaxScore != 100 {
		t.Errorf("expected max score 100, got %d", result.MaxScore)
	}

	if len(result.Categories) == 0 {
		t.Error("expected at least one category")
	}

	for _, cat := range result.Categories {
		if cat.Name == "" {
			t.Error("expected non-empty category name")
		}
		if len(cat.Checks) == 0 {
			t.Errorf("expected at least one check in category %s", cat.Name)
		}
	}
}

func TestFormatResult(t *testing.T) {
	result := &ScanResult{
		Timestamp:   time.Now(),
		OverallPass: true,
		Score:       90,
		MaxScore:    100,
		Categories: []Category{
			{
				Name: "test",
				Pass: true,
				Checks: []Check{
					{Name: "check1", Pass: true, Message: "ok"},
				},
			},
		},
	}

	formatted := FormatResult(result)
	if formatted == "" {
		t.Error("expected non-empty formatted result")
	}
}

func TestScoreFromResult(t *testing.T) {
	tests := []struct {
		score    int
		expected string
	}{
		{95, "Excellent"},
		{85, "Good"},
		{75, "Fair"},
		{65, "Poor"},
		{50, "Critical"},
	}

	for _, tt := range tests {
		result := &ScanResult{Score: tt.score}
		formatted := ScoreFromResult(result)
		if len(formatted) == 0 {
			t.Errorf("expected non-empty string for score %d", tt.score)
		}
	}
}

func TestScanResultToCheckItems(t *testing.T) {
	result := &ScanResult{
		Score:    80,
		MaxScore: 100,
		Categories: []Category{
			{
				Name: "firewall",
				Pass: true,
				Checks: []Check{
					{Name: "nftables", Pass: true, Message: "policy drop: true", Severity: "critical"},
				},
			},
			{
				Name: "kernel",
				Pass: false,
				Checks: []Check{
					{Name: "slab_nomerge", Pass: false, Message: "slab_nomerge: false", Severity: "medium"},
				},
			},
		},
	}

	items := ScanResultToCheckItems(result)
	if len(items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(items))
	}

	if items[0].Status != StatusPass {
		t.Errorf("expected pass for nftables, got %d", items[0].Status)
	}
	if items[1].Status != StatusWarn {
		t.Errorf("expected warn for slab_nomerge (medium severity), got %d", items[1].Status)
	}
}

func TestScanResultToCheckItemsHighSeverity(t *testing.T) {
	result := &ScanResult{
		Categories: []Category{
			{
				Name: "ssh",
				Pass: false,
				Checks: []Check{
					{Name: "password-auth", Pass: false, Message: "password auth: yes", Severity: "high"},
				},
			},
		},
	}

	items := ScanResultToCheckItems(result)
	if len(items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(items))
	}
	if items[0].Status != StatusFail {
		t.Errorf("expected fail for high severity check, got %d", items[0].Status)
	}
}
