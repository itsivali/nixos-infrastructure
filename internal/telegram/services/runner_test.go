package services

import (
	"strings"
	"testing"
)

func TestRunnerRun(t *testing.T) {
	runner := NewRunner()

	tests := []struct {
		name    string
		cmd     string
		timeout int
		want    string
	}{
		{"echo", "echo hello", 5, "hello"},
		{"exit code", "exit 1", 5, ""},
		{"timeout", "sleep 10", 1, "Command timed out"},
		{"empty", "", 5, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := runner.Run(tt.cmd, tt.timeout)
			if tt.name == "timeout" {
				if !strings.Contains(got, "timed out") {
					t.Errorf("Run(%q) = %q, want timeout message", tt.cmd, got)
				}
				return
			}
			if tt.name == "empty" || tt.name == "exit code" {
				return
			}
			if !strings.Contains(got, tt.want) {
				t.Errorf("Run(%q) = %q, want contains %q", tt.cmd, got, tt.want)
			}
		})
	}
}

func TestRunnerRunArgs(t *testing.T) {
	runner := NewRunner()

	output := runner.RunArgs(5, "echo", "hello", "world")
	if !strings.Contains(output, "hello world") {
		t.Errorf("RunArgs() = %q, want contains 'hello world'", output)
	}

	output = runner.RunArgs(5)
	if output != "" {
		t.Errorf("RunArgs() with no args = %q, want empty", output)
	}
}

func TestQuoteSh(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"hello", "'hello'"},
		{"it's", `'it'\''s'`},
		{"", "''"},
		{"a b c", "'a b c'"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := QuoteSh(tt.input)
			if got != tt.want {
				t.Errorf("QuoteSh(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestContainerCreation(t *testing.T) {
	container := NewContainer("/tmp/test")
	if container == nil {
		t.Fatal("expected non-nil container")
	}
	if container.Runner == nil {
		t.Fatal("expected non-nil runner")
	}
	if container.System == nil {
		t.Fatal("expected non-nil system service")
	}
	if container.Nix == nil {
		t.Fatal("expected non-nil nix service")
	}
	if container.Git == nil {
		t.Fatal("expected non-nil git service")
	}
	if container.GitOps == nil {
		t.Fatal("expected non-nil gitops service")
	}
	if container.Desktop == nil {
		t.Fatal("expected non-nil desktop service")
	}
	if container.Monitoring == nil {
		t.Fatal("expected non-nil monitoring service")
	}
	if container.Security == nil {
		t.Fatal("expected non-nil security service")
	}
	if container.Tailscale == nil {
		t.Fatal("expected non-nil tailscale service")
	}
	if container.Firewall == nil {
		t.Fatal("expected non-nil firewall service")
	}
	if container.Platform == nil {
		t.Fatal("expected non-nil platform service")
	}
}

func TestSystemServiceUptime(t *testing.T) {
	runner := NewRunner()
	svc := NewSystemService(runner)
	uptime := svc.Uptime()
	if uptime == "" {
		t.Error("expected non-empty uptime")
	}
}

func TestSystemServiceCPUCores(t *testing.T) {
	runner := NewRunner()
	svc := NewSystemService(runner)
	cores := svc.CPUCores()
	if cores == "" {
		t.Error("expected non-empty CPU cores")
	}
}

func TestSystemServiceDiskUsage(t *testing.T) {
	runner := NewRunner()
	svc := NewSystemService(runner)
	disk := svc.DiskUsage()
	if disk == "" {
		t.Error("expected non-empty disk usage")
	}
}

func TestSystemServiceLoadAvg(t *testing.T) {
	runner := NewRunner()
	svc := NewSystemService(runner)
	load := svc.LoadAvg()
	if load == "" {
		t.Error("expected non-empty load average")
	}
}

func TestNixServiceCurrentGeneration(t *testing.T) {
	runner := NewRunner()
	svc := NewNixService(runner, "/tmp/test")
	gen := svc.CurrentGeneration()
	if gen == "" {
		t.Error("expected non-empty generation")
	}
}
