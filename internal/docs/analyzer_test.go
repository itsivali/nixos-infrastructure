package docs

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/parser"
	"github.com/itsivali/nixos-infrastructure/internal/scanner"
)

func TestAnalyzeModule(t *testing.T) {
	tmpDir := t.TempDir()
	modPath := filepath.Join(tmpDir, "test.nix")

	// Match actual repo doc header format with triple # delimiters
	content := `##############################################################################
#
# Security Module
#
# Purpose
# -------
# Compose security-related configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
`
	if err := os.WriteFile(modPath, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	info, err := parser.Parse(modPath)
	if err != nil {
		t.Fatal(err)
	}

	analysis := AnalyzeModule(modPath, info)

	if !analysis.HasDocHeader {
		t.Error("Expected HasDocHeader to be true")
	}
	// Parser extracts purpose from doc header
	if analysis.DocQuality < 0.1 {
		t.Errorf("Expected DocQuality > 0.1, got %f", analysis.DocQuality)
	}
}

func TestAnalyzeModuleMinimal(t *testing.T) {
	tmpDir := t.TempDir()
	modPath := filepath.Join(tmpDir, "minimal.nix")

	content := `{ imports = [ ./foo.nix ]; }`
	if err := os.WriteFile(modPath, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	info, err := parser.Parse(modPath)
	if err != nil {
		t.Fatal(err)
	}

	analysis := AnalyzeModule(modPath, info)

	if analysis.HasDocHeader {
		t.Error("Expected HasDocHeader to be false")
	}
	if len(analysis.Suggestions) == 0 {
		t.Error("Expected suggestions for minimal module")
	}
}

func TestAnalyzeRepository(t *testing.T) {
	modules := []scanner.Module{
		{Path: "/test/mod1.nix", RelPath: "mod1.nix"},
		{Path: "/test/mod2.nix", RelPath: "mod2.nix"},
	}

	parsed := map[string]*parser.ModuleInfo{
		"/test/mod1.nix": {
			DocHeader: "Header with purpose section",
			Purpose:   "Test purpose",
		},
		"/test/mod2.nix": {
			DocHeader: "",
		},
	}

	metrics := AnalyzeRepository(modules, parsed)

	if metrics.TotalModules != 2 {
		t.Errorf("Expected 2 total modules, got %d", metrics.TotalModules)
	}
	if metrics.DocumentedModules != 1 {
		t.Errorf("Expected 1 documented module, got %d", metrics.DocumentedModules)
	}
	if metrics.CoveragePercent != 50.0 {
		t.Errorf("Expected 50%% coverage, got %f", metrics.CoveragePercent)
	}
}

func TestGenerateDocReport(t *testing.T) {
	modules := []scanner.Module{
		{Path: "/test/mod1.nix", RelPath: "mod1.nix"},
	}

	parsed := map[string]*parser.ModuleInfo{
		"/test/mod1.nix": {
			DocHeader: "Test header",
			Purpose:   "Test purpose",
		},
	}

	report := GenerateDocReport(modules, parsed)

	if report == "" {
		t.Error("Expected non-empty report")
	}
	if !contains(report, "Documentation Analysis Report") {
		t.Error("Expected report header")
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && (s[0:len(substr)] == substr || contains(s[1:], substr)))
}
