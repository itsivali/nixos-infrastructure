package graph

import (
	"fmt"
	"strings"
)

func (g *Graph) RenderMermaid() string {
	var b strings.Builder
	b.WriteString("graph TD;\n")

	for _, n := range g.Nodes {
		id := sanitizeMermaidID(n.ID)
		label := n.Label
		b.WriteString(fmt.Sprintf("    %s[%q];\n", id, label))
	}

	for _, e := range g.Edges {
		from := sanitizeMermaidID(e.From)
		to := sanitizeMermaidID(e.To)
		style := ""
		switch e.Type {
		case EdgeImport:
			style = "-->"
		case EdgeOwns:
			style = "-.->"
		case EdgeDependsOn:
			style = "==>"
		default:
			style = "---"
		}
		b.WriteString(fmt.Sprintf("    %s %s %s;\n", from, style, to))
	}

	return b.String()
}

func (g *Graph) RenderDOT() string {
	var b strings.Builder
	b.WriteString("digraph {\n")
	b.WriteString("    rankdir=LR;\n")
	b.WriteString("    node [shape=box, style=rounded];\n\n")

	for _, n := range g.Nodes {
		id := sanitizeDOTID(n.ID)
		b.WriteString(fmt.Sprintf("    %s [label=%q];\n", id, n.Label))
	}

	for _, e := range g.Edges {
		from := sanitizeDOTID(e.From)
		to := sanitizeDOTID(e.To)
		style := "solid"
		switch e.Type {
		case EdgeOwns:
			style = "dashed"
		case EdgeDependsOn:
			style = "bold"
		}
		b.WriteString(fmt.Sprintf("    %s -> %s [style=%s];\n", from, to, style))
	}

	b.WriteString("}\n")
	return b.String()
}

func (g *Graph) RenderDOTWithColors() string {
	var b strings.Builder
	b.WriteString("digraph {\n")
	b.WriteString("    rankdir=LR;\n")
	b.WriteString("    node [shape=box, style=filled, fontname=monospace];\n\n")
	b.WriteString("    // Node colors by category\n")

	for _, n := range g.Nodes {
		id := sanitizeDOTID(n.ID)
		color := nodeColor(n.Category)
		b.WriteString(fmt.Sprintf("    %s [label=%q, fillcolor=%q, fontcolor=%q];\n",
			id, n.Label, color, fontColor(color)))
	}

	for _, e := range g.Edges {
		from := sanitizeDOTID(e.From)
		to := sanitizeDOTID(e.To)
		style := "solid"
		switch e.Type {
		case EdgeOwns:
			style = "dashed"
		case EdgeDependsOn:
			style = "bold"
		}
		b.WriteString(fmt.Sprintf("    %s -> %s [style=%s];\n", from, to, style))
	}

	b.WriteString("}\n")
	return b.String()
}

func sanitizeMermaidID(s string) string {
	s = strings.ReplaceAll(s, "/", "_")
	s = strings.ReplaceAll(s, "-", "_")
	s = strings.ReplaceAll(s, ".", "_")
	s = strings.ReplaceAll(s, " ", "_")
	if s == "" {
		s = "root"
	}
	if s[0] >= '0' && s[0] <= '9' {
		s = "n_" + s
	}
	return s
}

func sanitizeDOTID(s string) string {
	s = strings.ReplaceAll(s, "/", "_")
	s = strings.ReplaceAll(s, "-", "_")
	s = strings.ReplaceAll(s, ".", "_")
	s = strings.ReplaceAll(s, " ", "_")
	if s == "" {
		s = "root"
	}
	if s[0] >= '0' && s[0] <= '9' {
		s = "n_" + s
	}
	return s
}

func nodeColor(cat interface{}) string {
	switch catStr := cat.(type) {
	case string:
		switch catStr {
		case "nixos":
			return "#7c3aed"
		case "home-manager":
			return "#0891b2"
		case "host":
			return "#059669"
		case "package":
			return "#d97706"
		case "library":
			return "#d7287e"
		case "script":
			return "#64748b"
		default:
			return "#1e293b"
		}
	}
	return "#1e293b"
}

func fontColor(bg string) string {
	darkColors := []string{"#7c3aed", "#059669", "#d97706", "#d7287e", "#64748b", "#1e293b"}
	for _, c := range darkColors {
		if bg == c {
			return "#ffffff"
		}
	}
	return "#000000"
}
