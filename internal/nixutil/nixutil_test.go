package nixutil

import (
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
