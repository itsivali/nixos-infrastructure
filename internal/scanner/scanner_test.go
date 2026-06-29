package scanner

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
}

func TestScan_RootFiles(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "flake.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "configuration.nix"), "{ }\n")

	s := New(dir)
	result, err := s.Scan()
	if err != nil {
		t.Fatal(err)
	}

	if len(result.ConfigFiles) != 2 {
		t.Errorf("expected 2 config files, got %d", len(result.ConfigFiles))
	}
	if result.TotalFiles != 2 {
		t.Errorf("expected TotalFiles=2, got %d", result.TotalFiles)
	}
}

func TestScan_NixOSDomain(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "networking", "default.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "networking", "networkmanager.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "networking", "time.nix"), "{ }\n")

	s := New(dir)
	result, err := s.Scan()
	if err != nil {
		t.Fatal(err)
	}

	if len(result.Domains) != 1 {
		t.Fatalf("expected 1 domain, got %d", len(result.Domains))
	}
	domain := result.Domains[0]
	if domain.Name != "networking" {
		t.Errorf("expected domain 'networking', got %q", domain.Name)
	}
	if domain.FileCount != 3 {
		t.Errorf("expected 3 files in domain, got %d", domain.FileCount)
	}
	if len(domain.Modules) != 3 {
		t.Errorf("expected 3 modules, got %d", len(domain.Modules))
	}
}

func TestScan_HomeManagerDomain(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "home", "git", "default.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "home", "git", "git.nix"), "{ }\n")

	s := New(dir)
	result, err := s.Scan()
	if err != nil {
		t.Fatal(err)
	}

	if len(result.HomeModules) != 1 {
		t.Fatalf("expected 1 home domain, got %d", len(result.HomeModules))
	}
	domain := result.HomeModules[0]
	if domain.Name != "git" {
		t.Errorf("expected domain 'git', got %q", domain.Name)
	}
}

func TestScan_Hosts(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "hosts", "pluto.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "hosts", "venus.nix"), "{ }\n")

	s := New(dir)
	result, err := s.Scan()
	if err != nil {
		t.Fatal(err)
	}

	if len(result.Hosts) != 2 {
		t.Errorf("expected 2 hosts, got %d", len(result.Hosts))
	}
}

func TestScan_Packages(t *testing.T) {
	dir := t.TempDir()
	// Package scanLevel uses includeDefault=false (skips default.nix)
	writeFile(t, filepath.Join(dir, "packages", "myapp", "cli.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "packages", "myapp", "desktop.nix"), "{ }\n")

	s := New(dir)
	result, err := s.Scan()
	if err != nil {
		t.Fatal(err)
	}

	if len(result.Packages) != 1 {
		t.Fatalf("expected 1 package set, got %d", len(result.Packages))
	}
	pkg := result.Packages[0]
	if pkg.Name != "myapp" {
		t.Errorf("expected package 'myapp', got %q", pkg.Name)
	}
	if pkg.FileCount != 2 {
		t.Errorf("expected 2 files in package, got %d", pkg.FileCount)
	}
}

func TestScan_Library(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "lib", "auto-imports.nix"), "{ }\n")

	s := New(dir)
	result, err := s.Scan()
	if err != nil {
		t.Fatal(err)
	}

	if len(result.LibModules) != 1 {
		t.Errorf("expected 1 lib module, got %d", len(result.LibModules))
	}
}

func TestScan_Excludes(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, ".git", "HEAD"), "")
	writeFile(t, filepath.Join(dir, "result", "some.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "_private", "secret.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "flake.nix"), "{ }\n")

	s := New(dir)
	result, err := s.Scan()
	if err != nil {
		t.Fatal(err)
	}

	if len(result.AllModules) != 1 {
		t.Errorf("expected only flake.nix, got %d modules", len(result.AllModules))
	}
}

func TestScan_SubdirsInDomain(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "observability", "default.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "observability", "prometheus.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "observability", "exporters", "node.nix"), "{ }\n")
	writeFile(t, filepath.Join(dir, "observability", "exporters", "default.nix"), "{ }\n")

	s := New(dir)
	result, err := s.Scan()
	if err != nil {
		t.Fatal(err)
	}

	if len(result.Domains) != 1 {
		t.Fatalf("expected 1 domain, got %d", len(result.Domains))
	}

	// Should find all 4 files in observability tree
	observedFiles := 0
	for _, m := range result.AllModules {
		if strings.HasPrefix(m.RelPath, "observability") {
			observedFiles++
		}
	}
	if observedFiles != 4 {
		t.Errorf("expected 4 modules in observability tree, got %d", observedFiles)
	}
}

func TestScan_EmptyDirectory(t *testing.T) {
	dir := t.TempDir()
	s := New(dir)
	result, err := s.Scan()
	if err != nil {
		t.Fatal(err)
	}
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if len(result.AllModules) != 0 {
		t.Errorf("expected 0 modules, got %d", len(result.AllModules))
	}
}

func TestModuleType(t *testing.T) {
	tests := []struct {
		name string
		want ModuleType
	}{
		{"default.nix", TypeEntry},
		{"options.nix", TypeOptions},
		{"my-options.nix", TypeOptions},
		{"_private.nix", TypePrivate},
		{"foo.nix", TypeRegular},
		{"bar.nix", TypeRegular},
	}
	for _, tt := range tests {
		got := moduleType(tt.name)
		if got != tt.want {
			t.Errorf("moduleType(%q) = %v, want %v", tt.name, got, tt.want)
		}
	}
}

func TestConfigCategory(t *testing.T) {
	if got := configCategory("configuration.nix"); got != CatConfig {
		t.Errorf("expected config, got %v", got)
	}
	if got := configCategory("flake.nix"); got != CatConfig {
		t.Errorf("expected config, got %v", got)
	}
}

func TestCountLines(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.nix")
	content := "line1\nline2\nline3\n"
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	if got := countLines(path); got != 3 {
		t.Errorf("expected 3 lines, got %d", got)
	}
}

func TestCountLines_EmptyFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "empty.nix")
	if err := os.WriteFile(path, nil, 0644); err != nil {
		t.Fatal(err)
	}
	if got := countLines(path); got != 0 {
		t.Errorf("expected 0 lines, got %d", got)
	}
}
