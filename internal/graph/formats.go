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


