package operations

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// Regression test for the reconciler generation-capture bug.
//
// Since 5386fb8 the reconciler runs as the unprivileged `ivali` user.
// The script used to capture the current/new generation with:
//
//	nix-env --list-generations --profile /nix/var/nix/profiles/system
//
// That opens the root-owned `/nix/var/nix/profiles/system.lock`, which
// fails with "Permission denied" under the `ivali` user and aborts every
// reconcile right after a successful fetch. NOPASSWD sudo covers only
// `nixos-rebuild`, not `nix-env`.
//
// Fixed by parsing the world-readable system profile symlink instead:
//
//	readlink /nix/var/nix/profiles/system | sed -E 's/.*system-([0-9]+)-link.*/\1/'
//
// Fixed in the same commit as this test.

func readReconcilerScript(t *testing.T) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "..", "scripts", "gitops-reconcile.sh"))
	if err != nil {
		t.Fatalf("read gitops-reconcile.sh: %v", err)
	}
	return string(data)
}

// The reconciler must never run the privileged nix-env profile-listing
// command, because the service runs as the unprivileged `ivali` user.
// Comment lines are ignored (they legitimately document the regression).
func TestReconcilerUsesRootlessGenerationCapture(t *testing.T) {
	script := readReconcilerScript(t)
	for _, line := range strings.Split(script, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "#") || trimmed == "" {
			continue
		}
		if strings.Contains(trimmed, "nix-env --list-generations") {
			t.Error("reconciler must not run `nix-env --list-generations`; it requires root-owned /nix/var/nix/profiles/system.lock")
		}
	}
}

// The rootless generation capture must be present in the script.
func TestReconcilerGenerationCaptureReadsProfileSymlink(t *testing.T) {
	script := readReconcilerScript(t)
	if !strings.Contains(script, "readlink /nix/var/nix/profiles/system") {
		t.Error("reconciler generation capture should read the system profile symlink via readlink")
	}
}

// The sed parse expression must correctly extract the generation number
// from a system profile symlink name (system-15-link -> 15). This runs
// the exact pipeline the reconciler script uses.
func TestGenerationParseExpression(t *testing.T) {
	dir := t.TempDir()
	// Model the real /nix/var/nix/profiles chain:
	//   system -> system-15-link -> /nix/store/...-nixos-system-prague
	store := filepath.Join(dir, "store", "abc-nixos-system-test")
	if err := os.MkdirAll(filepath.Dir(store), 0o755); err != nil {
		t.Fatalf("mkdir store: %v", err)
	}
	if err := os.WriteFile(store, []byte("x"), 0o644); err != nil {
		t.Fatalf("write store: %v", err)
	}
	profiles := filepath.Join(dir, "profiles")
	if err := os.MkdirAll(profiles, 0o755); err != nil {
		t.Fatalf("mkdir profiles: %v", err)
	}
	genLink := filepath.Join(profiles, "system-15-link")
	if err := os.Symlink(store, genLink); err != nil {
		t.Fatalf("symlink system-15-link: %v", err)
	}
	systemLink := filepath.Join(profiles, "system")
	if err := os.Symlink("system-15-link", systemLink); err != nil {
		t.Fatalf("symlink system: %v", err)
	}

	// Mirrors gitops-reconcile.sh's rootless generation parse.
	script := `readlink "$1" | sed -E 's/.*system-([0-9]+)-link.*/\1/'`
	cmd := exec.Command("bash", "-c", script, "bash", systemLink)
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("generation parse failed: %v", err)
	}
	if got := strings.TrimSpace(string(out)); got != "15" {
		t.Errorf("expected generation 15, got %q", got)
	}
}
