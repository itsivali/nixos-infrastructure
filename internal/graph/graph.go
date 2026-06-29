package graph

import (
	"fmt"
	"sort"
	"strings"

	"github.com/willisivali/nixos-infrastructure/internal/parser"
	"github.com/willisivali/nixos-infrastructure/internal/scanner"
)

type NodeType string

const (
	NodeModule  NodeType = "module"
	NodeOption  NodeType = "option"
	NodePackage NodeType = "package"
	NodeHost    NodeType = "host"
)

type EdgeType string

const (
	EdgeImport    EdgeType = "imports"
	EdgeOwns      EdgeType = "owns"
	EdgeDependsOn EdgeType = "depends-on"
)

type Node struct {
	ID       string   `json:"id"`
	Label    string   `json:"label"`
	Type     NodeType `json:"type"`
	Path     string   `json:"path"`
	Weight   int      `json:"weight"`
	Category scanner.ModuleCategory `json:"category,omitempty"`
}

type Edge struct {
	From string   `json:"from"`
	To   string   `json:"to"`
	Type EdgeType `json:"type"`
}

type Graph struct {
	Nodes []Node `json:"nodes"`
	Edges []Edge `json:"edges"`
}

type ViewOptions struct {
	Type  string // "tree", "deps", "ownership"
	Depth int
}

func Build(scannerResult *scanner.ScanResult, parsed map[string]*parser.ModuleInfo) *Graph {
	g := &Graph{}

	nodeSet := make(map[string]bool)
	addNode := func(id, label string, ntype NodeType, path string, cat scanner.ModuleCategory) {
		if nodeSet[id] {
			return
		}
		nodeSet[id] = true
		g.Nodes = append(g.Nodes, Node{
			ID:       id,
			Label:    label,
			Type:     ntype,
			Path:     path,
			Category: cat,
		})
	}

	// Add all modules as nodes
	for _, m := range scannerResult.AllModules {
		cat := m.Category
		ntype := NodeModule
		if cat == scanner.CatPackage {
			ntype = NodePackage
		} else if cat == scanner.CatHost {
			ntype = NodeHost
		}
		addNode(m.RelPath, shortName(m.RelPath), ntype, m.Path, cat)
	}

	// Add domains as nodes
	for _, d := range scannerResult.Domains {
		addNode(d.RelPath, d.Name, NodeModule, d.Path, d.Category)
	}

	// Add edges from imports
	for _, m := range scannerResult.AllModules {
		if info, ok := parsed[m.Path]; ok {
			for _, imp := range info.Imports {
				if imp == "<auto-imports>" {
					continue
				}
				if nodeSet[imp] {
					g.Edges = append(g.Edges, Edge{
						From: m.RelPath,
						To:   imp,
						Type: EdgeImport,
					})
				}
			}
		}
	}

	// Compute node weights (number of dependents)
	weightMap := make(map[string]int)
	for _, e := range g.Edges {
		weightMap[e.To]++
	}
	for i, n := range g.Nodes {
		g.Nodes[i].Weight = weightMap[n.ID]
	}

	return g
}

func (g *Graph) RenderTree(t Terminal, opts ViewOptions) string {
	if len(g.Nodes) == 0 {
		return ""
	}

	var b strings.Builder

	// Build adjacency (parent -> children via imports reversed)
	childrenOf := make(map[string][]string)
	for _, e := range g.Edges {
		if e.Type == EdgeImport {
			childrenOf[e.From] = append(childrenOf[e.From], e.To)
		}
	}

	// Find roots (nodes that nothing imports)
	imported := make(map[string]bool)
	for _, e := range g.Edges {
		if e.Type == EdgeImport {
			imported[e.To] = true
		}
	}

	var roots []Node
	for _, n := range g.Nodes {
		if !imported[n.ID] && n.Type == NodeModule {
			roots = append(roots, n)
		}
	}

	sort.Slice(roots, func(i, j int) bool {
		return roots[i].Label < roots[j].Label
	})

	// Render tree
	depth := opts.Depth
	if depth <= 0 {
		depth = 10
	}

	var render func(id string, level int)
	render = func(id string, level int) {
		if level > depth {
			return
		}

		prefix := ""
		if level == 0 {
			prefix = t.Dim("└─ ")
		} else {
			prefix = strings.Repeat("    ", level-1)
			if level > 0 {
				prefix += t.Dim("├─ ")
			}
		}

		node := g.findNode(id)
		if node == nil {
			return
		}

		label := t.Bold(node.Label)
		info := t.Dim(fmt.Sprintf("(%s)", node.Category))
		b.WriteString(fmt.Sprintf("  %s%s %s\n", prefix, label, info))

		for _, child := range childrenOf[id] {
			render(child, level+1)
		}
	}

	for _, root := range roots {
		render(root.ID, 0)
	}

	return b.String()
}

func (g *Graph) RenderDeps(t Terminal) string {
	var b strings.Builder

	// Group edges by source
	depsOf := make(map[string][]string)
	for _, e := range g.Edges {
		if e.Type == EdgeImport {
			depsOf[e.From] = append(depsOf[e.From], e.To)
		}
	}

	// Sort sources
	var sources []string
	for k := range depsOf {
		sources = append(sources, k)
	}
	sort.Strings(sources)

	for _, src := range sources {
		deps := depsOf[src]
		if len(deps) == 0 {
			continue
		}

		b.WriteString(fmt.Sprintf("  %s\n", t.Bold(shortName(src))))

		sort.Strings(deps)
		for _, dep := range deps {
			b.WriteString(fmt.Sprintf("    %s %s\n",
				t.Dim("→"),
				t.Dim(dep)))
		}
		b.WriteString("\n")
	}

	return b.String()
}

func (g *Graph) findNode(id string) *Node {
	for i := range g.Nodes {
		if g.Nodes[i].ID == id {
			return &g.Nodes[i]
		}
	}
	return nil
}

func shortName(path string) string {
	parts := strings.Split(path, "/")
	if len(parts) > 0 {
		return parts[len(parts)-1]
	}
	return path
}

type Terminal interface {
	Dim(s string) string
	Bold(s string) string
}
