package graph

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/parser"
	"github.com/itsivali/nixos-infrastructure/internal/scanner"
)

type mockTerminal struct{}

func (m mockTerminal) Dim(s string) string  { return s }
func (m mockTerminal) Bold(s string) string { return s }
func (m mockTerminal) Code(s string) string { return s }

func TestBuild_Empty(t *testing.T) {
	g := Build(&scanner.ScanResult{}, nil)
	if g == nil {
		t.Fatal("expected non-nil graph")
	}
	if len(g.Nodes) != 0 {
		t.Errorf("expected 0 nodes, got %d", len(g.Nodes))
	}
}

func TestBuild_ModulesOnly(t *testing.T) {
	result := &scanner.ScanResult{
		AllModules: []scanner.Module{
			{Path: "/a.nix", RelPath: "a.nix", Category: scanner.CatNixOS},
			{Path: "/b.nix", RelPath: "b.nix", Category: scanner.CatNixOS},
		},
	}
	g := Build(result, nil)
	if len(g.Nodes) != 2 {
		t.Errorf("expected 2 nodes, got %d", len(g.Nodes))
	}
}

func TestBuild_ImportEdges(t *testing.T) {
	result := &scanner.ScanResult{
		AllModules: []scanner.Module{
			{Path: "/dir/a.nix", RelPath: "dir/a.nix", Category: scanner.CatNixOS},
			{Path: "/dir/b.nix", RelPath: "dir/b.nix", Category: scanner.CatNixOS},
		},
	}
	parsed := map[string]*parser.ModuleInfo{
		"/dir/a.nix": {
			Path:    "/dir/a.nix",
			RelPath: "dir/a.nix",
			Imports: []string{"./b.nix"},
		},
	}
	g := Build(result, parsed)

	foundEdge := false
	for _, e := range g.Edges {
		if e.From == "dir/a.nix" && e.To == "dir/b.nix" && e.Type == EdgeImport {
			foundEdge = true
			break
		}
	}
	if !foundEdge {
		t.Error("expected import edge from dir/a.nix to dir/b.nix")
	}
}

func TestBuild_OwnershipEdges(t *testing.T) {
	result := &scanner.ScanResult{
		AllModules: []scanner.Module{
			{Path: "/mod.nix", RelPath: "mod.nix", Category: scanner.CatNixOS},
			{Path: "/sub/owned.nix", RelPath: "sub/owned.nix", Category: scanner.CatNixOS},
		},
	}
	parsed := map[string]*parser.ModuleInfo{
		"/mod.nix": {
			Path:    "/mod.nix",
			RelPath: "mod.nix",
			Owns:    []string{"sub/owned.nix"},
		},
	}
	g := Build(result, parsed)

	foundEdge := false
	for _, e := range g.Edges {
		if e.From == "mod.nix" && e.To == "sub/owned.nix" && e.Type == EdgeOwns {
			foundEdge = true
			break
		}
	}
	if !foundEdge {
		t.Error("expected ownership edge from mod.nix to sub/owned.nix")
	}
}

func TestBuild_AutoImportSkipped(t *testing.T) {
	result := &scanner.ScanResult{
		AllModules: []scanner.Module{
			{Path: "/dir/a.nix", RelPath: "dir/a.nix", Category: scanner.CatNixOS},
		},
	}
	parsed := map[string]*parser.ModuleInfo{
		"/dir/a.nix": {
			Path:         "/dir/a.nix",
			RelPath:      "dir/a.nix",
			Imports:      []string{"<auto-imports>", "./self.nix"},
			IsAutoImport: true,
		},
	}
	g := Build(result, parsed)

	for _, e := range g.Edges {
		if e.Type == EdgeImport && (strings.Contains(e.To, "auto-imports") || e.To == "<auto-imports>") {
			t.Errorf("expected no auto-import edges, found: %s -> %s", e.From, e.To)
		}
	}
}

func TestRenderTree_Basic(t *testing.T) {
	result := &scanner.ScanResult{
		AllModules: []scanner.Module{
			{Path: "/root.nix", RelPath: "root.nix", Category: scanner.CatNixOS},
		},
	}
	g := Build(result, nil)
	out := g.RenderTree(mockTerminal{}, ViewOptions{Type: "tree", Depth: 3})
	if !strings.Contains(out, "root.nix") {
		t.Errorf("expected root.nix in tree output, got: %s", out)
	}
}

func TestRenderDeps_Basic(t *testing.T) {
	result := &scanner.ScanResult{
		AllModules: []scanner.Module{
			{Path: "/a.nix", RelPath: "a.nix", Category: scanner.CatNixOS},
			{Path: "/b.nix", RelPath: "b.nix", Category: scanner.CatNixOS},
		},
	}
	parsed := map[string]*parser.ModuleInfo{
		"/a.nix": {Path: "/a.nix", RelPath: "a.nix", Imports: []string{"./b.nix"}},
	}
	g := Build(result, parsed)
	out := g.RenderDeps(mockTerminal{})
	if !strings.Contains(out, "b.nix") {
		t.Errorf("expected b.nix in deps output, got: %s", out)
	}
}

func TestRenderOwnership_Empty(t *testing.T) {
	g := Build(&scanner.ScanResult{}, nil)
	out := g.RenderOwnership(mockTerminal{})
	if !strings.Contains(out, "No ownership") {
		t.Errorf("expected 'No ownership' message, got: %s", out)
	}
}

func TestRenderOwnership_WithEdges(t *testing.T) {
	result := &scanner.ScanResult{
		AllModules: []scanner.Module{
			{Path: "/mod.nix", RelPath: "mod.nix", Category: scanner.CatNixOS},
			{Path: "/owned.nix", RelPath: "owned.nix", Category: scanner.CatNixOS},
		},
	}
	parsed := map[string]*parser.ModuleInfo{
		"/mod.nix": {Path: "/mod.nix", RelPath: "mod.nix", Owns: []string{"owned.nix"}},
	}
	g := Build(result, parsed)
	out := g.RenderOwnership(mockTerminal{})
	if !strings.Contains(out, "owned.nix") {
		t.Errorf("expected owned.nix in ownership output, got: %s", out)
	}
}

func TestShortName(t *testing.T) {
	tests := []struct {
		path string
		want string
	}{
		{"a.nix", "a.nix"},
		{"dir/b.nix", "b.nix"},
		{"a/b/c.nix", "c.nix"},
		{"", ""},
	}
	for _, tt := range tests {
		got := shortName(tt.path)
		if got != tt.want {
			t.Errorf("shortName(%q) = %q, want %q", tt.path, got, tt.want)
		}
	}
}

func TestFindNode(t *testing.T) {
	g := &Graph{
		Nodes: []Node{
			{ID: "a.nix", Label: "a"},
			{ID: "b.nix", Label: "b"},
		},
	}
	if n := g.findNode("a.nix"); n == nil {
		t.Error("expected to find a.nix")
	}
	if n := g.findNode("b.nix"); n == nil {
		t.Error("expected to find b.nix")
	}
	if n := g.findNode("c.nix"); n != nil {
		t.Error("expected not to find c.nix")
	}
}

func TestImportResolution(t *testing.T) {
	result := &scanner.ScanResult{
		AllModules: []scanner.Module{
			{Path: filepath.Join("/repo", "dir", "a.nix"), RelPath: "dir/a.nix", Category: scanner.CatNixOS},
			{Path: filepath.Join("/repo", "dir", "b.nix"), RelPath: "dir/b.nix", Category: scanner.CatNixOS},
		},
	}
	parsed := map[string]*parser.ModuleInfo{
		filepath.Join("/repo", "dir", "a.nix"): {
			Path:    filepath.Join("/repo", "dir", "a.nix"),
			RelPath: "dir/a.nix",
			Imports: []string{"./b.nix"},
		},
	}
	g := Build(result, parsed)

	found := false
	for _, e := range g.Edges {
		if e.Type == EdgeImport && e.From == "dir/a.nix" && e.To == "dir/b.nix" {
			found = true
			break
		}
	}
	if !found {
		t.Error("expected import to resolve dir/a.nix -> dir/b.nix")
	}
}
