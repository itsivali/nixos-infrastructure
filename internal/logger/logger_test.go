package logger

import (
	"bytes"
	"testing"
)

func TestParseLevel(t *testing.T) {
	tests := []struct {
		input string
		want  Level
	}{
		{"trace", Trace},
		{"debug", Debug},
		{"verbose", Verbose},
		{"info", Info},
		{"warn", Warn},
		{"warning", Warn},
		{"error", Error},
		{"fatal", Fatal},
		{"INFO", Info},
		{"Debug", Debug},
		{"unknown", Info},
		{"", Info},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := ParseLevel(tt.input)
			if got != tt.want {
				t.Errorf("ParseLevel(%q) = %v, want %v", tt.input, got, tt.want)
			}
		})
	}
}

func TestNew(t *testing.T) {
	l := New(Info)
	if l == nil {
		t.Fatal("New() returned nil")
	}
	if l.Level() != Info {
		t.Errorf("expected level Info, got %v", l.Level())
	}
}

func TestNewWithCaller(t *testing.T) {
	l := New(Debug, WithCaller(true))
	if l == nil {
		t.Fatal("New() returned nil")
	}
	if !l.caller {
		t.Error("expected caller to be enabled")
	}
}

func TestNewWithLevel(t *testing.T) {
	l := New(Info, WithLevel(Error))
	if l.Level() != Error {
		t.Errorf("expected level Error, got %v", l.Level())
	}
}

func TestSetLevel(t *testing.T) {
	l := New(Info)
	l.SetLevel(Debug)
	if l.Level() != Debug {
		t.Errorf("expected level Debug after SetLevel, got %v", l.Level())
	}
}

func TestNewJSON(t *testing.T) {
	var buf bytes.Buffer
	l := NewJSON(&buf, Debug)
	if l == nil {
		t.Fatal("NewJSON() returned nil")
	}
	if l.Level() != Debug {
		t.Errorf("expected level Debug, got %v", l.Level())
	}
}

func TestVerboseLevel(t *testing.T) {
	l := New(Verbose)
	event := l.Verbose()
	if event == nil {
		t.Error("Verbose() returned nil when level is Verbose")
	}

	l2 := New(Info)
	event2 := l2.Verbose()
	if event2 != nil {
		t.Error("Verbose() returned nil when level is Info (expected nil)")
	}
}

func TestZLevel(t *testing.T) {
	tests := []struct {
		level Level
		want  string
	}{
		{Trace, "trace"},
		{Debug, "debug"},
		{Verbose, "debug"},
		{Info, "info"},
		{Warn, "warn"},
		{Error, "error"},
		{Fatal, "fatal"},
	}

	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			l := New(tt.level)
			zl := l.zLevel()
			if zl.String() != tt.want {
				t.Errorf("zLevel() = %v, want %v", zl.String(), tt.want)
			}
		})
	}
}

func TestColorize(t *testing.T) {
	result := colorize("test", 32)
	if result == "" {
		t.Error("colorize() returned empty string")
	}
	if result == "test" {
		t.Error("colorize() did not apply color")
	}
}

func TestItoa(t *testing.T) {
	tests := []struct {
		n    int
		want string
	}{
		{0, "0"},
		{1, "1"},
		{10, "10"},
		{90, "90"},
		{255, "255"},
	}

	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			got := itoa(tt.n)
			if got != tt.want {
				t.Errorf("itoa(%d) = %q, want %q", tt.n, got, tt.want)
			}
		})
	}
}

func TestShortCaller(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"internal/config/config.go", "config.go"},
		{"github.com/user/repo/internal/cmd/cmd.go", "cmd.go"},
		{"simple.go", "simple.go"},
		{"", ""},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := shortCaller(tt.input)
			if got != tt.want {
				t.Errorf("shortCaller(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}
