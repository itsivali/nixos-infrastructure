package parser

import (
	"os"
	"path/filepath"
	"testing"
)

func parseStr(t *testing.T, content string) *ModuleInfo {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "test.nix")
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	info, err := Parse(path)
	if err != nil {
		t.Fatal(err)
	}
	return info
}

func assertContains(t *testing.T, slice []string, want string) {
	t.Helper()
	for _, s := range slice {
		if s == want {
			return
		}
	}
	t.Errorf("expected slice to contain %q, got %v", want, slice)
}

func assertNotContains(t *testing.T, slice []string, want string) {
	t.Helper()
	for _, s := range slice {
		if s == want {
			t.Errorf("expected slice not to contain %q", want)
			return
		}
	}
}

// ── Parse ────────────────────────────────────────────────────────────

func TestParse(t *testing.T) {
	info := parseStr(t, "{ }\n")
	if info == nil {
		t.Fatal("expected non-nil info")
	}
}

// ── Doc Header ───────────────────────────────────────────────────────

func TestExtractDocHeader_Basic(t *testing.T) {
	info := parseStr(t, `###
# mymodule
#
# Purpose
# -----
# Handles widget configuration
###

{ ... }`)
	if info.DocHeader == "" {
		t.Fatal("expected doc header")
	}
}

func TestExtractDocHeader_MultiHash(t *testing.T) {
	info := parseStr(t, `###
# mymodule
#
# Purpose
# -----
# Thing
###`)
	if info.DocHeader == "" {
		t.Fatal("expected doc header")
	}
}

func TestExtractDocHeader_None(t *testing.T) {
	info := parseStr(t, `{ ... }`)
	if info.DocHeader != "" {
		t.Errorf("expected no doc header, got %q", info.DocHeader)
	}
}

// ── Purpose ──────────────────────────────────────────────────────────

func TestExtractPurpose_FromHeader(t *testing.T) {
	info := parseStr(t, `###
# Purpose
# -----
# Configures the foo bar
###`)

	if info.Purpose != "Configures the foo bar" {
		t.Errorf("expected purpose from header, got %q", info.Purpose)
	}
}

func TestExtractPurpose_FromContentWithoutHeader(t *testing.T) {
	// Purpose extracted from raw content (no doc header block)
	info := parseStr(t, "{\n}\n\nPurpose\n-----\nA thing")
	if info.Purpose != "A thing" {
		t.Errorf("expected purpose from content, got %q", info.Purpose)
	}
}

func TestExtractPurpose_None(t *testing.T) {
	info := parseStr(t, "{ }")
	if info.Purpose != "" {
		t.Errorf("expected no purpose, got %q", info.Purpose)
	}
}

// ── Owns ─────────────────────────────────────────────────────────────

func TestExtractOwns_Basic(t *testing.T) {
	info := parseStr(t, "{\n}\n\nOwns\n----\n- home/git/default.nix")
	if len(info.Owns) == 0 {
		t.Fatal("expected owns entries")
	}
	assertContains(t, info.Owns, "home/git/default.nix")
}

func TestExtractOwns_None(t *testing.T) {
	info := parseStr(t, "{ }")
	if len(info.Owns) != 0 {
		t.Errorf("expected no owns, got %v", info.Owns)
	}
}

// ── Imports ──────────────────────────────────────────────────────────

func TestExtractImports_AutoImport(t *testing.T) {
	info := parseStr(t, `{ imports = import ../lib/auto-imports.nix ./.; }`)
	assertContains(t, info.Imports, "<auto-imports>")
}

func TestExtractImports_SingleLine(t *testing.T) {
	info := parseStr(t, `imports = [ ./foo.nix ./bar.nix ];`)
	assertContains(t, info.Imports, "./foo.nix")
	assertContains(t, info.Imports, "./bar.nix")
}

func TestExtractImports_MultiLine(t *testing.T) {
	content := `imports = [
    ./foo.nix
    ./bar.nix
  ];`
	info := parseStr(t, content)
	assertContains(t, info.Imports, "./foo.nix")
	assertContains(t, info.Imports, "./bar.nix")
}

func TestExtractImports_CommentsSkipped(t *testing.T) {
	content := `imports = [
    # this is a comment
    ./real.nix
    // another comment
  ];`
	info := parseStr(t, content)
	assertContains(t, info.Imports, "./real.nix")
	assertNotContains(t, info.Imports, "# this is a comment")
}

func TestExtractImports_NoImports(t *testing.T) {
	info := parseStr(t, `{ foo = "bar"; }`)
	if len(info.Imports) != 0 {
		t.Errorf("expected no imports, got %v", info.Imports)
	}
}

func TestExtractImports_SemicolonInLine(t *testing.T) {
	info := parseStr(t, `imports = [
    ./foo.nix;
    ./bar.nix;
  ];`)
	assertContains(t, info.Imports, "./foo.nix")
	assertContains(t, info.Imports, "./bar.nix")
}

func TestExtractImports_AutoImportAndRegular(t *testing.T) {
	info := parseStr(t, `imports = import ../lib/auto-imports.nix [ ./extra.nix ];`)
	assertContains(t, info.Imports, "<auto-imports>")
	assertContains(t, info.Imports, "./extra.nix")
}

// ── Options Detection ────────────────────────────────────────────────

func TestHasOptions_True(t *testing.T) {
	info := parseStr(t, `{ options = {
    enable = mkEnableOption "foo";
  }; }`)
	if !info.HasOptions {
		t.Error("expected HasOptions to be true")
	}
}

func TestHasOptions_False(t *testing.T) {
	info := parseStr(t, `imports = [ ./foo.nix ];`)
	if info.HasOptions {
		t.Error("expected HasOptions to be false")
	}
}

// ── Auto-Import Detection ───────────────────────────────────────────

func TestIsAutoImport_True(t *testing.T) {
	info := parseStr(t, `{ imports = import ../lib/auto-imports.nix ./.; }`)
	if !info.IsAutoImport {
		t.Error("expected IsAutoImport to be true")
	}
}

func TestIsAutoImport_DeepPath(t *testing.T) {
	info := parseStr(t, `{ imports = import ../../lib/auto-imports.nix ./.; }`)
	if !info.IsAutoImport {
		t.Error("expected IsAutoImport to be true for deep paths")
	}
}

func TestIsAutoImport_False(t *testing.T) {
	info := parseStr(t, `imports = [ ./foo.nix ];`)
	if info.IsAutoImport {
		t.Error("expected IsAutoImport to be false")
	}
}

// ── Edge Cases ───────────────────────────────────────────────────────

func TestParse_EmptyFile(t *testing.T) {
	info := parseStr(t, "")
	if info == nil {
		t.Fatal("expected non-nil info")
	}
}

func TestParse_MinimalFile(t *testing.T) {
	info := parseStr(t, "{ }")
	if info == nil {
		t.Fatal("expected non-nil info")
	}
}

func TestExtractImports_CommentThenImport(t *testing.T) {
	info := parseStr(t, `# Top comment
#
imports = [
    ./a.nix
    # inline comment
    ./b.nix
  ];`)
	assertContains(t, info.Imports, "./a.nix")
	assertContains(t, info.Imports, "./b.nix")
}

func TestExtractDocHeader_WithOwnership(t *testing.T) {
	info := parseStr(t, `###
# Ownership
# ---------
# - home/git/default.nix
###`)
	if info.Purpose != "" {
		t.Errorf("expected no purpose, got %q", info.Purpose)
	}
	if len(info.Owns) == 0 {
		t.Fatal("expected owns from header")
	}
	assertContains(t, info.Owns, "home/git/default.nix")
}
