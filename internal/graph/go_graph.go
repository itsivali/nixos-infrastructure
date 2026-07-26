package graph

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

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

	walkFn := func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			if strings.HasPrefix(info.Name(), ".") || info.Name() == "vendor" || info.Name() == "node_modules" {
				return filepath.SkipDir
			}
			if strings.HasPrefix(filepath.Base(path), "_") {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}

		dir := filepath.Dir(path)
		relDir, _ := filepath.Rel(root, dir)
		importPath := filepath.ToSlash(gg.Module + "/" + relDir)

		if _, exists := pkgMap[importPath]; !exists {
			pkgMap[importPath] = &GoPackage{
				Path:       relDir,
				ImportPath: importPath,
			}
		}
		pkgMap[importPath].Files++

		content, err := os.ReadFile(path)
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

	if err := filepath.Walk(filepath.Join(root, "internal"), walkFn); err != nil {
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
