package repository

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/parser"
	"github.com/itsivali/nixos-infrastructure/internal/scanner"
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

func writeFlake(t *testing.T, dir string, content string) string {
	t.Helper()
	flakePath := filepath.Join(dir, "flake.nix")
	if content == "" {
		content = "{ inputs = { nixpkgs.url = \"github:NixOS/nixpkgs/nixos-unstable\"; }; }\n"
	}
	writeFile(t, flakePath, content)
	return flakePath
}

// ── Detect ───────────────────────────────────────────────────────────

func TestDetect_Found(t *testing.T) {
	dir := t.TempDir()
	writeFlake(t, dir, "")
	repo, ok := Detect(dir)
	if !ok {
		t.Fatal("expected to detect repository")
	}
	if repo.Root != dir {
		t.Errorf("expected root %q, got %q", dir, repo.Root)
	}
}

func TestDetect_NotFound(t *testing.T) {
	dir := t.TempDir()
	_, ok := Detect(dir)
	if ok {
		t.Fatal("expected not to detect repository without flake.nix")
	}
}

func TestDetect_WalksUp(t *testing.T) {
	dir := t.TempDir()
	writeFlake(t, dir, "")
	subdir := filepath.Join(dir, "a", "b")
	if err := os.MkdirAll(subdir, 0o755); err != nil {
		t.Fatal(err)
	}
	repo, ok := Detect(subdir)
	if !ok {
		t.Fatal("expected to detect repository by walking up")
	}
	if repo.Root != dir {
		t.Errorf("expected root %q, got %q", dir, repo.Root)
	}
}

// ── Counts / Lists ───────────────────────────────────────────────────

func TestModuleCount_Empty(t *testing.T) {
	r := &Repository{}
	n, hm, total := r.ModuleCount()
	if n != 0 || hm != 0 || total != 0 {
		t.Errorf("expected 0, got %d, %d, %d", n, hm, total)
	}
}

func TestModuleCount_WithModules(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			AllModules: []scanner.Module{
				{Category: scanner.CatNixOS},
				{Category: scanner.CatNixOS},
				{Category: scanner.CatHomeManager},
			},
		},
	}
	n, hm, total := r.ModuleCount()
	if n != 2 {
		t.Errorf("expected 2 NixOS, got %d", n)
	}
	if hm != 1 {
		t.Errorf("expected 1 HM, got %d", hm)
	}
	if total != 3 {
		t.Errorf("expected 3 total, got %d", total)
	}
}

func TestFileCount(t *testing.T) {
	tests := []struct {
		name   string
		repo   *Repository
		expect int
	}{
		{"nil result", &Repository{}, 0},
		{"with files", &Repository{Result: &scanner.ScanResult{TotalFiles: 5}}, 5},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.repo.FileCount(); got != tt.expect {
				t.Errorf("got %d, want %d", got, tt.expect)
			}
		})
	}
}

func TestDomainList(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			Domains: []scanner.Domain{
				{Name: "boot"},
				{Name: "networking"},
				{Name: "security"},
			},
		},
	}
	domains := r.DomainList()
	if len(domains) != 3 {
		t.Fatalf("expected 3 domains, got %d", len(domains))
	}
	if domains[0] != "boot" || domains[1] != "networking" || domains[2] != "security" {
		t.Errorf("expected sorted domains, got %v", domains)
	}
}

func TestHostList(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			Hosts: []scanner.Module{
				{Path: "/hosts/pluto.nix"},
				{Path: "/hosts/venus.nix"},
			},
		},
	}
	hosts := r.HostList()
	if len(hosts) != 2 {
		t.Fatalf("expected 2 hosts, got %d", len(hosts))
	}
	if hosts[0] != "pluto" || hosts[1] != "venus" {
		t.Errorf("expected host names, got %v", hosts)
	}
}

func TestPackageCount(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			Packages: []scanner.Domain{
				{Modules: []scanner.Module{{}, {}}},
				{Modules: []scanner.Module{{}}},
			},
		},
	}
	if got := r.PackageCount(); got != 3 {
		t.Errorf("expected 3, got %d", got)
	}
}

func TestPackageCount_Empty(t *testing.T) {
	r := &Repository{}
	if got := r.PackageCount(); got != 0 {
		t.Errorf("expected 0, got %d", got)
	}
}

// ── FlakeInputs ──────────────────────────────────────────────────────

func TestFlakeInputs(t *testing.T) {
	dir := t.TempDir()
	writeFlake(t, dir, `{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };
}
`)
	r := &Repository{Root: dir}
	if got := r.FlakeInputs(); got != 2 {
		t.Errorf("expected 2 inputs, got %d", got)
	}
}

func TestFlakeInputs_NoFlake(t *testing.T) {
	r := &Repository{Root: t.TempDir()}
	if got := r.FlakeInputs(); got != 0 {
		t.Errorf("expected 0, got %d", got)
	}
}

// ── Check Methods ────────────────────────────────────────────────────

func TestCheckDuplicateImports_None(t *testing.T) {
	r := &Repository{}
	if got := r.CheckDuplicateImports(); got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestCheckDuplicateImports(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{},
		Parsed: map[string]*parser.ModuleInfo{
			"/a.nix": {RelPath: "a.nix", Imports: []string{"./shared.nix"}},
			"/b.nix": {RelPath: "b.nix", Imports: []string{"./shared.nix"}},
		},
	}
	dups := r.CheckDuplicateImports()
	if len(dups) != 1 {
		t.Fatalf("expected 1 duplicate, got %d: %v", len(dups), dups)
	}
	if !strings.Contains(dups[0], "./shared.nix") {
		t.Errorf("expected shared.nix in duplicate message, got %q", dups[0])
	}
}

func TestCheckOrphanModules_Empty(t *testing.T) {
	r := &Repository{}
	if got := r.CheckOrphanModules(); got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestCheckOrphanModules(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			AllModules: []scanner.Module{
				{Path: "/dir/regular.nix", RelPath: "dir/regular.nix", Type: scanner.TypeRegular},
			},
		},
		Parsed: map[string]*parser.ModuleInfo{
			"/dir/regular.nix": {Path: "/dir/regular.nix", RelPath: "dir/regular.nix", Imports: nil},
		},
	}
	orphans := r.CheckOrphanModules()
	if len(orphans) != 1 {
		t.Errorf("expected 1 orphan, got %d: %v", len(orphans), orphans)
	}
}

func TestCheckOrphanModules_SkipsEntryTypes(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			AllModules: []scanner.Module{
				{Path: "/dir/default.nix", RelPath: "dir/default.nix", Type: scanner.TypeEntry},
				{Path: "/dir/_private.nix", RelPath: "dir/_private.nix", Type: scanner.TypePrivate},
			},
		},
		Parsed: map[string]*parser.ModuleInfo{
			"/dir/default.nix":  {Path: "/dir/default.nix", RelPath: "dir/default.nix", Imports: nil},
			"/dir/_private.nix": {Path: "/dir/_private.nix", RelPath: "dir/_private.nix", Imports: nil},
		},
	}
	orphans := r.CheckOrphanModules()
	if len(orphans) != 0 {
		t.Errorf("expected 0 orphans (entry/private skipped), got %d", len(orphans))
	}
}

func TestCheckOrphanModules_SkipsAutoImportDirs(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			AllModules: []scanner.Module{
				{Path: "/dir/regular.nix", RelPath: "dir/regular.nix", Type: scanner.TypeRegular},
			},
		},
		Parsed: map[string]*parser.ModuleInfo{
			"/dir/default.nix": {Path: "/dir/default.nix", RelPath: "dir/default.nix", IsAutoImport: true},
			"/dir/regular.nix": {Path: "/dir/regular.nix", RelPath: "dir/regular.nix", Imports: nil},
		},
	}
	orphans := r.CheckOrphanModules()
	if len(orphans) != 0 {
		t.Errorf("expected 0 orphans (auto-import dir), got %d", len(orphans))
	}
}

func TestCheckMissingDocHeaders(t *testing.T) {
	r := &Repository{
		Parsed: map[string]*parser.ModuleInfo{
			"/a.nix": {RelPath: "a.nix", DocHeader: "header", IsAutoImport: false},
			"/b.nix": {RelPath: "b.nix", DocHeader: "", IsAutoImport: false},
			"/c.nix": {RelPath: "c.nix", DocHeader: "", IsAutoImport: true},
		},
	}
	missing := r.CheckMissingDocHeaders()
	if len(missing) != 1 {
		t.Errorf("expected 1 missing header, got %d: %v", len(missing), missing)
	}
	if missing[0] != "b.nix" {
		t.Errorf("expected b.nix, got %s", missing[0])
	}
}

func TestCheckModulesWithOptions(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			AllModules: []scanner.Module{
				{Path: "/a.nix", RelPath: "a.nix"},
				{Path: "/b.nix", RelPath: "b.nix"},
			},
		},
		Parsed: map[string]*parser.ModuleInfo{
			"/a.nix": {RelPath: "a.nix", HasOptions: true},
			"/b.nix": {RelPath: "b.nix", HasOptions: false},
		},
	}
	opts := r.CheckModulesWithOptions()
	if len(opts) != 1 || opts[0] != "a.nix" {
		t.Errorf("expected [a.nix], got %v", opts)
	}
}

// ── FindModule ───────────────────────────────────────────────────────

func TestFindModule_NotFound(t *testing.T) {
	r := &Repository{}
	_, _, ok := r.FindModule("anything")
	if ok {
		t.Error("expected not found")
	}
}

func TestFindModule_Exact(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			AllModules: []scanner.Module{
				{Path: "/dir/m.nix", RelPath: "dir/m.nix"},
			},
		},
		Parsed: map[string]*parser.ModuleInfo{
			"/dir/m.nix": {RelPath: "dir/m.nix"},
		},
	}
	_, _, ok := r.FindModule("dir/m.nix")
	if !ok {
		t.Error("expected to find exact match")
	}
}

func TestFindModule_Partial(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			AllModules: []scanner.Module{
				{Path: "/some/very/long/path/m.nix", RelPath: "some/very/long/path/m.nix"},
			},
		},
		Parsed: map[string]*parser.ModuleInfo{
			"/some/very/long/path/m.nix": {RelPath: "some/very/long/path/m.nix"},
		},
	}
	_, _, ok := r.FindModule("m.nix")
	if !ok {
		t.Error("expected partial match")
	}
}

// ── HealthSummary ────────────────────────────────────────────────────

func TestHealthSummary_Empty(t *testing.T) {
	r := &Repository{}
	s := r.HealthSummary()
	if s["status"] != "unknown" {
		t.Errorf("expected unknown status, got %q", s["status"])
	}
}

func TestHealthSummary_Healthy(t *testing.T) {
	r := &Repository{
		Result: &scanner.ScanResult{
			AllModules: []scanner.Module{{Path: "/a.nix", RelPath: "a.nix"}},
		},
		Parsed: map[string]*parser.ModuleInfo{
			"/a.nix": {RelPath: "a.nix", Imports: []string{}},
		},
	}
	s := r.HealthSummary()
	if s["modules"] != "1 total" {
		t.Errorf("unexpected modules summary: %q", s["modules"])
	}
}

// ── ClearCache ──────────────────────────────────────────────────────

func TestClearCache(t *testing.T) {
	dir := t.TempDir()
	writeFlake(t, dir, "")
	repo, _ := Detect(dir)
	if err := repo.Scan(); err != nil {
		t.Fatal(err)
	}
	if repo.Result == nil {
		t.Fatal("expected result after scan")
	}

	repo.ClearCache()
	if repo.Result != nil {
		t.Error("expected nil result after clear")
	}
	if repo.Parsed != nil {
		t.Error("expected nil parsed after clear")
	}
}

func TestClearCache_RemovesFile(t *testing.T) {
	dir := t.TempDir()
	writeFlake(t, dir, "")
	repo, _ := Detect(dir)

	// trigger cache save by scanning
	if err := repo.Scan(); err != nil {
		t.Fatal(err)
	}
	cachePath := repo.cachePath()
	if _, err := os.Stat(cachePath); os.IsNotExist(err) {
		t.Fatal("expected cache file to exist")
	}

	repo.ClearCache()
	if _, err := os.Stat(cachePath); !os.IsNotExist(err) {
		t.Error("expected cache file to be removed")
	}
}
