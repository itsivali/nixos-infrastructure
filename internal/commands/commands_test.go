package commands

import (
	"testing"

	"github.com/willisivali/nixos-infrastructure/internal/parser"
	"github.com/willisivali/nixos-infrastructure/internal/scanner"
)

// ── splitCommandLine ─────────────────────────────────────────────────

func TestSplitCommandLine(t *testing.T) {
	tests := []struct {
		input   string
		wantCmd string
		wantArg string
	}{
		{"status", "status", ""},
		{"doctor --verbose", "doctor", "--verbose"},
		{"extract shell", "extract", "shell"},
		{"graph tree --depth 5", "graph", "tree --depth 5"},
		{"", "", ""},
		{"   ", "", ""},
	}
	for _, tt := range tests {
		result := splitCommandLine(tt.input)
		if result[0] != tt.wantCmd || result[1] != tt.wantArg {
			t.Errorf("splitCommandLine(%q) = (%q, %q), want (%q, %q)",
				tt.input, result[0], result[1], tt.wantCmd, tt.wantArg)
		}
	}
}

// ── joinHosts ────────────────────────────────────────────────────────

func TestJoinHosts(t *testing.T) {
	tests := []struct {
		hosts []string
		want  string
	}{
		{[]string{"pluto", "venus"}, "pluto, venus"},
		{[]string{"pluto"}, "pluto"},
		{nil, ""},
		{[]string{}, ""},
	}
	for _, tt := range tests {
		got := joinHosts(tt.hosts)
		if got != tt.want {
			t.Errorf("joinHosts(%v) = %q, want %q", tt.hosts, got, tt.want)
		}
	}
}

// ── filterByPrefix ───────────────────────────────────────────────────

func TestFilterByPrefix(t *testing.T) {
	modules := []scanner.Module{
		{RelPath: "home/shell/aliases/git.nix"},
		{RelPath: "home/shell/core/zsh.nix"},
		{RelPath: "home/git/default.nix"},
		{RelPath: "networking/default.nix"},
	}

	shell := filterByPrefix(modules, "home/shell")
	if len(shell) != 2 {
		t.Errorf("expected 2 shell modules, got %d", len(shell))
	}

	git := filterByPrefix(modules, "home/git")
	if len(git) != 1 {
		t.Errorf("expected 1 git module, got %d", len(git))
	}

	none := filterByPrefix(modules, "nonexistent")
	if len(none) != 0 {
		t.Errorf("expected 0, got %d", len(none))
	}

	all := filterByPrefix(modules, "")
	if len(all) != 4 {
		t.Errorf("expected 4, got %d", len(all))
	}
}

func TestFilterByPrefix_Sorted(t *testing.T) {
	modules := []scanner.Module{
		{RelPath: "z/mod.nix"},
		{RelPath: "a/mod.nix"},
		{RelPath: "m/mod.nix"},
	}
	result := filterByPrefix(modules, "")
	if result[0].RelPath != "a/mod.nix" {
		t.Errorf("expected sorted, first=%q", result[0].RelPath)
	}
	if result[2].RelPath != "z/mod.nix" {
		t.Errorf("expected sorted, last=%q", result[2].RelPath)
	}
}

// ── findModulesWithPattern ───────────────────────────────────────────

func TestFindModulesWithPattern(t *testing.T) {
	modules := []scanner.Module{
		{Path: "/a/foo.nix", RelPath: "a/foo.nix"},
		{Path: "/home/git/git.nix", RelPath: "home/git/git.nix"},
	}
	parsed := map[string]*parser.ModuleInfo{
		"/a/foo.nix":        {RelPath: "a/foo.nix", Purpose: "Configure git stuff"},
		"/home/git/git.nix": {RelPath: "home/git/git.nix", Purpose: "Git config"},
	}

	// Should find a/foo.nix (has "git" in purpose), skip home/git/git.nix
	result := findModulesWithPattern(modules, parsed, "programs.git")
	if len(result) != 0 {
		t.Errorf("expected 0 matches, got %d: %v", len(result), result)
	}
}

// ── findGithubPackages ───────────────────────────────────────────────

func TestFindGithubPackages(t *testing.T) {
	modules := []scanner.Module{
		{Path: "/home/git/git.nix", RelPath: "home/git/git.nix"},
		{Path: "/home/git/delta.nix", RelPath: "home/git/delta.nix"},
	}
	parsed := map[string]*parser.ModuleInfo{
		"/home/git/git.nix":   {RelPath: "home/git/git.nix", Purpose: "Git config"},
		"/home/git/delta.nix": {RelPath: "home/git/delta.nix", Purpose: ""},
	}

	result := findGithubPackages(modules, parsed)
	if len(result) != 2 {
		t.Errorf("expected 2 packages, got %d: %v", len(result), result)
	}
}

func TestFindGithubPackages_Empty(t *testing.T) {
	result := findGithubPackages(nil, nil)
	if len(result) != 0 {
		t.Errorf("expected 0, got %d", len(result))
	}
}

// ── resolveImportRel ─────────────────────────────────────────────────

func TestResolveImportRel(t *testing.T) {
	tests := []struct {
		moduleRel string
		imp       string
		want      string
	}{
		{"home/git/default.nix", "./git.nix", "home/git/git.nix"},
		{"home/git/default.nix", "./packages.nix", "home/git/packages.nix"},
		{"networking/default.nix", "./networkmanager.nix", "networking/networkmanager.nix"},
		{"dir/a.nix", "../lib/b.nix", "lib/b.nix"},
		{"a/b/c.nix", "../../root.nix", "root.nix"},
	}
	for _, tt := range tests {
		got := resolveImportRel(tt.moduleRel, tt.imp)
		if got != tt.want {
			t.Errorf("resolveImportRel(%q, %q) = %q, want %q",
				tt.moduleRel, tt.imp, got, tt.want)
		}
	}
}

// ── findImporters ────────────────────────────────────────────────────

func TestFindImporters_Found(t *testing.T) {
	modules := []scanner.Module{
		{Path: "/a.nix", RelPath: "a.nix"},
		{Path: "/b.nix", RelPath: "b.nix"},
	}
	parsed := map[string]*parser.ModuleInfo{
		"/a.nix": {Imports: []string{"./b.nix"}},
		"/b.nix": {Imports: []string{}},
	}

	result := findImporters(modules, parsed, "b.nix")
	if len(result) != 1 || result[0] != "a.nix" {
		t.Errorf("expected [a.nix], got %v", result)
	}
}

func TestFindImporters_None(t *testing.T) {
	modules := []scanner.Module{
		{Path: "/a.nix", RelPath: "a.nix"},
	}
	parsed := map[string]*parser.ModuleInfo{
		"/a.nix": {Imports: []string{"./self.nix"}},
	}

	result := findImporters(modules, parsed, "b.nix")
	if len(result) != 0 {
		t.Errorf("expected 0, got %d", len(result))
	}
}

func TestFindImporters_NilParsed(t *testing.T) {
	result := findImporters([]scanner.Module{{Path: "/a.nix", RelPath: "a.nix"}}, nil, "a.nix")
	if len(result) != 0 {
		t.Errorf("expected 0, got %d", len(result))
	}
}
