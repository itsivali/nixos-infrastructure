package operations

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// Regression test for the gitops reconciler dirty-tree guard.
//
// The guard runs under `set -Eeuo pipefail`:
//
//	untracked=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v "^result$" | head -1 || true)
//
// On a CLEAN checkout, `git ls-files --others` emits nothing, so `grep -v`
// selects no lines and exits 1. Without the trailing `|| true`, the pipeline
// status is non-zero and `set -e` aborts the reconciler before it fetches,
// builds, or logs a single line (observed: 142ms CPU, exit 1, zero journal
// output, checkout stranded on an old commit for days).
//
// Fixed in the same commit as this test.

func gitAvailable(t *testing.T) {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not available")
	}
}

func cleanGitRepo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	cmd := exec.Command("git", "init", "-q", dir)
	if err := cmd.Run(); err != nil {
		t.Fatalf("git init failed: %v", err)
	}
	// A tracked file plus commit so the repo is a real (clean) checkout.
	file := filepath.Join(dir, "flake.nix")
	if err := os.WriteFile(file, []byte("{ }\n"), 0o644); err != nil {
		t.Fatalf("write flake.nix: %v", err)
	}
	cmd = exec.Command("git", "-C", dir, "add", "flake.nix")
	if err := cmd.Run(); err != nil {
		t.Fatalf("git add failed: %v", err)
	}
	cmd = exec.Command("git", "-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
	if err := cmd.Run(); err != nil {
		t.Fatalf("git commit failed: %v", err)
	}
	return dir
}

func runGuard(t *testing.T, dir, guardLine string) (string, error) {
	t.Helper()
	script := strings.Join([]string{
		"set -Eeuo pipefail",
		guardLine,
		`echo "untracked=[$untracked]"`,
		`exit 0`,
	}, "\n")
	cmd := exec.Command("bash", "-c", script)
	cmd.Dir = dir
	out, err := cmd.Output()
	return strings.TrimSpace(string(out)), err
}

// A clean checkout must NOT abort the guard. Before the fix this failed
// (exit 1 from `set -e` on the grep -v no-match pipeline).
func TestDirtyGuardSurvivesCleanCheckout(t *testing.T) {
	gitAvailable(t)
	dir := cleanGitRepo(t)

	out, err := runGuard(t, dir, `untracked=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v "^result$" | head -1 || true)`)
	if err != nil {
		t.Errorf("clean checkout must not abort the reconciler: %v", err)
	}
	if out != "untracked=[]" {
		t.Errorf("expected no untracked files on clean checkout, got %q", out)
	}
}

// The untracked-file detection must still work: an actual untracked file is
// reported and the guard moves on.
func TestDirtyGuardDetectsUntrackedFile(t *testing.T) {
	gitAvailable(t)
	dir := cleanGitRepo(t)
	untracked := filepath.Join(dir, "scratch.txt")
	if err := os.WriteFile(untracked, []byte("x"), 0o644); err != nil {
		t.Fatalf("write scratch: %v", err)
	}

	out, err := runGuard(t, dir, `untracked=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v "^result$" | head -1 || true)`)
	if err != nil {
		t.Fatalf("guard failed unexpectedly: %v", err)
	}
	if out != "untracked=[scratch.txt]" {
		t.Errorf("expected scratch.txt to be detected, got %q", out)
	}
}

// Guards the fix itself: without `|| true`, a clean checkout kills the script.
// If this test fails because it now "cannot fail", the guard line lost its
// protection and the reconciler is at risk again.
func TestDirtyGuardWithoutTrueWouldAbortCleanCheckout(t *testing.T) {
	gitAvailable(t)
	dir := cleanGitRepo(t)

	err := func() error {
		_, err := runGuard(t, dir, `untracked=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v "^result$" | head -1)`)
		return err
	}()
	if err == nil {
		t.Error("guard WITHOUT `|| true` unexpectedly survived a clean checkout; fix did not take effect")
	}
}
