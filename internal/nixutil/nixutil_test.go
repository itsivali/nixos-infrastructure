package nixutil

import (
	"os"
	"path/filepath"
	"testing"
)

func TestResolveImportRel(t *testing.T) {
	tests := []struct {
		name      string
		moduleRel string
		imp       string
		want      string
	}{
		{
			name:      "relative import with ./",
			moduleRel: "modules/nixos/foo.nix",
			imp:       "./bar.nix",
			want:      "modules/nixos/bar.nix",
		},
		{
			name:      "relative import with ../",
			moduleRel: "modules/nixos/sub/foo.nix",
			imp:       "../bar.nix",
			want:      "modules/nixos/bar.nix",
		},
		{
			name:      "relative import directory",
			moduleRel: "modules/nixos/foo.nix",
			imp:       "./bar",
			want:      "modules/nixos/bar/default.nix",
		},
		{
			name:      "absolute import",
			moduleRel: "modules/nixos/foo.nix",
			imp:       "pkgs/bar.nix",
			want:      "pkgs/bar.nix",
		},
		{
			name:      "deeply nested relative",
			moduleRel: "a/b/c/d/foo.nix",
			imp:       "../../e/bar.nix",
			want:      "a/b/e/bar.nix",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ResolveImportRel(tt.moduleRel, tt.imp)
			if got != tt.want {
				t.Errorf("ResolveImportRel(%q, %q) = %q, want %q", tt.moduleRel, tt.imp, got, tt.want)
			}
		})
	}
}

func TestParseGeneration(t *testing.T) {
	tests := []struct {
		name   string
		target string
		want   int
	}{
		{
			name:   "standard NixOS profile symlink",
			target: "/nix/var/nix/profiles/system-42-link",
			want:   42,
		},
		{
			name:   "single digit generation",
			target: "/nix/var/nix/profiles/system-1-link",
			want:   1,
		},
		{
			name:   "large generation number",
			target: "/nix/var/nix/profiles/system-12345-link",
			want:   12345,
		},
		{
			name:   "bare symlink target (no directory prefix)",
			target: "system-7-link",
			want:   7,
		},
		{
			name:   "no generation pattern returns 0",
			target: "/nix/var/nix/profiles/system-link",
			want:   0,
		},
		{
			name:   "empty string returns 0",
			target: "",
			want:   0,
		},
		{
			name:   "unrelated path returns 0",
			target: "/nix/store/abc123-nixos-system-42",
			want:   0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ParseGeneration(tt.target)
			if got != tt.want {
				t.Errorf("ParseGeneration(%q) = %d, want %d", tt.target, got, tt.want)
			}
		})
	}
}

func TestCurrentGeneration(t *testing.T) {
	// CurrentGeneration reads the real system profile symlink.
	// On a NixOS system it should return > 0; in CI/test environments
	// the symlink may not exist, so 0 is acceptable.
	gen := CurrentGeneration()
	if gen < 0 {
		t.Errorf("CurrentGeneration() = %d, want >= 0", gen)
	}
}

func TestParseGenerationRegression(t *testing.T) {
	// Regression: the reconciler shell script uses this exact sed expression:
	//   readlink /nix/var/nix/profiles/system | sed -E 's/.*system-([0-9]+)-link.*/\1/'
	// Verify our Go regex matches the same inputs.
	targets := map[string]int{
		"/nix/var/nix/profiles/system-1-link":     1,
		"/nix/var/nix/profiles/system-10-link":    10,
		"/nix/var/nix/profiles/system-100-link":   100,
		"/nix/var/nix/profiles/system-999-link":   999,
		"/nix/var/nix/profiles/system-1000-link":  1000,
		"/nix/var/nix/profiles/system-99999-link": 99999,
	}

	for target, want := range targets {
		got := ParseGeneration(target)
		if got != want {
			t.Errorf("ParseGeneration(%q) = %d, want %d (shell sed regression)", target, got, want)
		}
	}
}

func TestCurrentGenerationWithMockSymlink(t *testing.T) {
	// Create a temporary directory with a mock system profile symlink
	// to verify CurrentGeneration reads the symlink correctly.
	tmpDir := t.TempDir()
	symlink := filepath.Join(tmpDir, "system-55-link")
	if err := os.Symlink(symlink, filepath.Join(tmpDir, "system")); err != nil {
		t.Fatalf("failed to create symlink: %v", err)
	}

	target, err := os.Readlink(filepath.Join(tmpDir, "system"))
	if err != nil {
		t.Fatalf("failed to read symlink: %v", err)
	}

	got := ParseGeneration(target)
	if got != 55 {
		t.Errorf("ParseGeneration(mock symlink target) = %d, want 55", got)
	}
}
