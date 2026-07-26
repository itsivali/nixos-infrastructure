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

func TestSeverityColor(t *testing.T) {
	tests := []struct {
		severity string
		expected string
	}{
		{"critical", "\033[1;31m"},
		{"high", "\033[0;31m"},
		{"medium", "\033[0;33m"},
		{"low", "\033[0;36m"},
		{"unknown", "\033[0m"},
	}

	for _, tt := range tests {
		color := SeverityColor(tt.severity)
		if color != tt.expected {
			t.Errorf("expected %s for severity %s, got %s", tt.expected, tt.severity, color)
		}
	}
}

func TestParseScore(t *testing.T) {
	tests := []struct {
		input    string
		expected int
	}{
		{"85", 85},
		{"100", 100},
		{"0", 0},
		{"invalid", 0},
	}

	for _, tt := range tests {
		result := ParseScore(tt.input)
		if result != tt.expected {
			t.Errorf("expected %d for input %s, got %d", tt.expected, tt.input, result)
		}
	}
}

func TestParseBool(t *testing.T) {
	tests := []struct {
		input    string
		expected bool
	}{
		{"true", true},
		{"1", true},
		{"yes", true},
		{"false", false},
		{"0", false},
		{"no", false},
		{"", false},
	}

	for _, tt := range tests {
		result := ParseBool(tt.input)
		if result != tt.expected {
			t.Errorf("expected %v for input %s, got %v", tt.expected, tt.input, result)
		}
	}
}

func TestParseInt(t *testing.T) {
	tests := []struct {
		input    string
		expected int
	}{
		{"85", 85},
		{"100", 100},
		{"0", 0},
		{"invalid", 0},
	}

	for _, tt := range tests {
		result := ParseInt(tt.input)
		if result != tt.expected {
			t.Errorf("expected %d for input %s, got %d", tt.expected, tt.input, result)
		}
	}
}
