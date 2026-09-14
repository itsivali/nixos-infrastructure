package graph

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// rootFS adapts *os.Root to the fs.FS interface for WalkDir/ReadFile.
type rootFS struct {
	root *os.Root
}

func (r rootFS) Open(name string) (fs.File, error) {
	return r.root.Open(name)
}

type GoGraphJSON struct {
	Module   string          `json:"module"`
	Packages []GoPackageJSON `json:"packages"`
	Edges    []GoEdgeJSON    `json:"edges"`
}

type GoPackageJSON struct {
	Path       string `json:"path"`
	ImportPath string `json:"import_path"`
	Files      int    `json:"files"`
}

type GoEdgeJSON struct {
	From string `json:"from"`
	To   string `json:"to"`
}

func (gg *GoGraph) ToJSON() ([]byte, error) {
	jsonGraph := GoGraphJSON{
		Module:   gg.Module,
		Packages: make([]GoPackageJSON, len(gg.Packages)),
		Edges:    make([]GoEdgeJSON, len(gg.Edges)),
	}

	for i, pkg := range gg.Packages {
		jsonGraph.Packages[i] = GoPackageJSON(pkg)
	}

	for i, edge := range gg.Edges {
		jsonGraph.Edges[i] = GoEdgeJSON(edge)
	}

	return json.MarshalIndent(jsonGraph, "", "  ")
}

type GoGraph struct {
	Module   string
	Packages []GoPackage
	Edges    []GoEdge
}

type GoPackage struct {
	Path       string
	ImportPath string
	Files      int
}

type GoEdge struct {
	From string
	To   string
}

func BuildGoGraph(root string) (*GoGraph, error) {
	gg := &GoGraph{}

	modPath := filepath.Join(root, "go.mod")
	data, err := os.ReadFile(modPath)
	if err != nil {
		return nil, fmt.Errorf("reading go.mod: %w", err)
	}

	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "module ") {
			gg.Module = strings.TrimSpace(strings.TrimPrefix(line, "module "))
			break
		}
	}

	pkgMap := make(map[string]*GoPackage)
	importMap := make(map[string]map[string]bool)

	internalRoot, err := os.OpenRoot(filepath.Join(root, "internal"))
	if err != nil {
		return nil, fmt.Errorf("opening internal dir: %w", err)
	}
	defer internalRoot.Close()

	internalFS := rootFS{root: internalRoot}

	// #nosec G122 -- os.Root-scoped handle prevents TOCTOU/symlink traversal
	// during the walk (root-scoped APIs per gosec recommendation).
	walkFn := func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			if strings.HasPrefix(d.Name(), ".") || d.Name() == "vendor" || d.Name() == "node_modules" {
				return fs.SkipDir
			}
			if strings.HasPrefix(filepath.Base(path), "_") {
				return fs.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}

		dir := filepath.Dir(path)
		relDir := "internal"
		if dir != "." {
			relDir = filepath.Join("internal", dir)
		}
		importPath := filepath.ToSlash(gg.Module + "/" + relDir)

		if _, exists := pkgMap[importPath]; !exists {
			pkgMap[importPath] = &GoPackage{
				Path:       relDir,
				ImportPath: importPath,
			}
		}
		pkgMap[importPath].Files++

		content, err := fs.ReadFile(internalFS, path)
		if err != nil {
			return nil
		}

		for _, line := range strings.Split(string(content), "\n") {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "import (") || line == "import" {
				continue
			}
			if strings.HasPrefix(line, "\t\"") && strings.Contains(line, gg.Module) {
				imp := extractImport(line, gg.Module)
				if imp != "" && imp != importPath {
					if importMap[importPath] == nil {
						importMap[importPath] = make(map[string]bool)
					}
					importMap[importPath][imp] = true
				}
			}
		}
		return nil
	}

	if err := fs.WalkDir(internalFS, ".", walkFn); err != nil {
		return nil, fmt.Errorf("walking internal: %w", err)
	}

	for path, pkg := range pkgMap {
		gg.Packages = append(gg.Packages, *pkg)
		if deps, ok := importMap[path]; ok {
			for dep := range deps {
				gg.Edges = append(gg.Edges, GoEdge{From: path, To: dep})
			}
		}
	}

	sort.Slice(gg.Packages, func(i, j int) bool {
		return gg.Packages[i].ImportPath < gg.Packages[j].ImportPath
	})

	return gg, nil
}

func extractImport(line, module string) string {
	line = strings.TrimSpace(line)
	line = strings.TrimPrefix(line, "\"")
	line = strings.TrimSuffix(line, "\",")
	line = strings.TrimSuffix(line, "\"")
	if strings.Contains(line, module) {
		parts := strings.Fields(line)
		if len(parts) > 0 {
			imp := parts[len(parts)-1]
			imp = strings.Trim(imp, "\"")
			return imp
		}
	}
	return ""
}

func (gg *GoGraph) RenderMermaid() string {
	var b strings.Builder
	b.WriteString("graph TD;\n")
	b.WriteString(fmt.Sprintf("    subgraph %q\n", gg.Module))

	for _, pkg := range gg.Packages {
		id := sanitizeMermaidID(pkg.ImportPath)
		b.WriteString(fmt.Sprintf("    %s[%q];\n", id, pkg.Path))
	}

	b.WriteString("    end\n")

	for _, e := range gg.Edges {
		from := sanitizeMermaidID(e.From)
		to := sanitizeMermaidID(e.To)
		b.WriteString(fmt.Sprintf("    %s --> %s;\n", from, to))
	}

	return b.String()
}
