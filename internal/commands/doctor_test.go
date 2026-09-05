package commands

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

// fakeLinterDir creates a temp dir with fake `name` executables that exit
// with the given code, and prepends it to PATH for the duration of the test.
func fakeLinterDir(t *testing.T, names map[string]int) string {
	t.Helper()
	bin := t.TempDir()
	for name, code := range names {
		script := "#!/bin/sh\nexit " + itoa(code) + "\n"
		if err := os.WriteFile(filepath.Join(bin, name), []byte(script), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	old := os.Getenv("PATH")
	t.Setenv("PATH", bin+string(os.PathListSeparator)+old)
	return bin
}

func itoa(n int) string {
	return string(rune('0' + n))
}

func TestRunLintToolAbsentIsPass(t *testing.T) {
	if got := runLintTool("definitely-not-a-real-linter-xyz", t.TempDir()); got != terminal.StatusPass {
		t.Errorf("expected PASS for missing optional linter, got %v", got)
	}
}

func TestRunLintToolCleanIsPass(t *testing.T) {
	fakeLinterDir(t, map[string]int{"deadnix": 0, "statix": 0})
	if got := runLintTool("deadnix", t.TempDir()); got != terminal.StatusPass {
		t.Errorf("expected PASS for clean deadnix, got %v", got)
	}
	if got := runLintTool("statix", t.TempDir()); got != terminal.StatusPass {
		t.Errorf("expected PASS for clean statix, got %v", got)
	}
}

func TestRunLintToolFindingsIsWarn(t *testing.T) {
	fakeLinterDir(t, map[string]int{"deadnix": 1, "statix": 1})
	if got := runLintTool("deadnix", t.TempDir()); got != terminal.StatusWarn {
		t.Errorf("expected WARN for dirty deadnix, got %v", got)
	}
	if got := runLintTool("statix", t.TempDir()); got != terminal.StatusWarn {
		t.Errorf("expected WARN for dirty statix, got %v", got)
	}
}
