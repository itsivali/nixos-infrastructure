//go:build integration

package commands

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func buildBinary(t *testing.T) string {
	t.Helper()
	repoRoot, err := findRepoRoot()
	if err != nil {
		t.Fatalf("find repo root: %v", err)
	}
	binary := filepath.Join(t.TempDir(), "ivali")
	cmd := exec.Command("go", "build", "-o", binary, "./cmd/ivali/")
	cmd.Dir = repoRoot
	cmd.Env = append(os.Environ(), "CGO_ENABLED=0")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("build failed: %v\n%s", err, out)
	}
	return binary
}

func findRepoRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "flake.nix")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", os.ErrNotExist
		}
		dir = parent
	}
}

func runIvali(t *testing.T, binary string, args ...string) (string, int) {
	t.Helper()
	repoRoot, err := findRepoRoot()
	if err != nil {
		t.Fatalf("find repo root: %v", err)
	}
	cmd := exec.Command(binary, args...)
	cmd.Dir = repoRoot
	env := os.Environ()
	// Ensure --json output doesn't get styled
	cmd.Env = append(env, "NO_COLOR=1", "CLICOLOR=0")
	out, err := cmd.CombinedOutput()
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			t.Fatalf("run failed: %v", err)
		}
	}
	return string(out), exitCode
}

func TestIntegrationStatus(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "status")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "Modules") {
		t.Errorf("expected output to contain 'Modules', got:\n%s", output)
	}
	if !strings.Contains(output, "Domains") {
		t.Errorf("expected output to contain 'Domains', got:\n%s", output)
	}
}

func TestIntegrationDoctor(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "doctor")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "Doctor Report") {
		t.Errorf("expected 'Doctor Report' in output")
	}
	if !strings.Contains(output, "Formatting") {
		t.Errorf("expected 'Formatting' in output")
	}
}

func TestIntegrationDoctorFix(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "doctor", "--fix")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "Applying Fixes") {
		t.Errorf("expected 'Applying Fixes' in output")
	}
	if !strings.Contains(output, "nix fmt") {
		t.Errorf("expected 'nix fmt' in output")
	}
}

func TestIntegrationExplain(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "explain", "flake.nix")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "Module: flake.nix") {
		t.Errorf("expected 'Module: flake.nix' in output:\n%s", output)
	}
	if !strings.Contains(output, "Category") {
		t.Errorf("expected 'Category' in output:\n%s", output)
	}
}

func TestIntegrationExplainNotFound(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "explain", "nonexistent")
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if !strings.Contains(output, "not found") {
		t.Errorf("expected 'not found' in output:\n%s", output)
	}
}

func TestIntegrationScan(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "scan")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "modules") {
		t.Errorf("expected 'modules' in output")
	}
}

func TestIntegrationSuggest(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "suggest")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "Suggestions") {
		t.Errorf("expected 'Suggestions' in output")
	}
}

func TestIntegrationGraphTree(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "graph", "tree")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "flake.nix") {
		t.Errorf("expected 'flake.nix' in graph tree output:\n%s", output)
	}
}

func TestIntegrationGraphOwnership(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "graph", "ownership")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "ownership") {
		t.Errorf("expected 'ownership' in graph ownership output:\n%s", output)
	}
}

func TestIntegrationExtractShell(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "extract", "shell")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "Shell") {
		t.Errorf("expected 'Shell' in output")
	}
}

func TestIntegrationExtractGit(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "extract", "git")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "Git") {
		t.Errorf("expected 'Git' in output")
	}
}

func TestIntegrationVerbose(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "--verbose", "status")
	if code != 0 {
		t.Errorf("expected exit 0, got %d\noutput:\n%s", code, output)
	}
	if !strings.Contains(output, "Repository Status") {
		t.Errorf("expected 'Repository Status' in output:\n%s", output)
	}
}

func TestIntegrationHelp(t *testing.T) {
	binary := buildBinary(t)
	output, code := runIvali(t, binary, "--help")
	if code != 0 {
		t.Errorf("expected exit 0, got %d", code)
	}
	if !strings.Contains(output, "IVALI") {
		t.Errorf("expected 'IVALI' in help output")
	}
	if !strings.Contains(output, "Repository Commands") {
		t.Errorf("expected 'Repository Commands' in help output")
	}
	if !strings.Contains(output, "Operations") {
		t.Errorf("expected 'Operations' in help output")
	}
}
