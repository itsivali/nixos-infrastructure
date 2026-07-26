package commands

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/graph"
)

type graphFormat string

const (
	formatText    graphFormat = "text"
	formatMermaid graphFormat = "mermaid"
	formatDOT     graphFormat = "dot"
	formatJSON    graphFormat = "json"
)

func CmdGraph(a *app.App) *cobra.Command {
	var depth int
	var format string

	cmd := &cobra.Command{
		Use:   "graph",
		Short: "Display module, dependency, and Go package graphs",
		Long: `Display import hierarchy, dependency relationships,
and Go package dependency graphs.

Subcommands:
  tree          Show Nix module import tree
  deps          Show flat dependency list
  ownership     Show module ownership relationships
  go-deps       Show Go package dependency graph

Flags:
  --format      Output format: text (default), mermaid, dot, json
  --depth       Tree depth limit (default: 3)`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	cmd.PersistentFlags().IntVarP(&depth, "depth", "d", 3, "Tree depth limit")
	cmd.PersistentFlags().StringVar(&format, "format", "text", "Output format (text, mermaid, dot, json)")

	treeCmd := &cobra.Command{
		Use:   "tree",
		Short: "Show module import tree",
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			r := a.Repo
			g := graph.Build(r.Result, r.Parsed)
			opts := graph.ViewOptions{Type: "tree", Depth: depth}

			switch graphFormat(format) {
			case formatMermaid:
				fmt.Println(g.RenderMermaid())
			case formatDOT:
				fmt.Println(g.RenderDOT())
			default:
				out := g.RenderTree(a.Term, opts)
				if out != "" {
					fmt.Println()
					fmt.Println(a.Term.InfoBox(out))
					fmt.Println()
				}
			}
			return nil
		},
	}

	depsCmd := &cobra.Command{
		Use:   "deps",
		Short: "Show flat dependency list",
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			r := a.Repo
			g := graph.Build(r.Result, r.Parsed)

			switch graphFormat(format) {
			case formatMermaid:
				fmt.Println(g.RenderMermaid())
			case formatDOT:
				fmt.Println(g.RenderDOT())
			default:
				out := g.RenderDeps(a.Term)
				if out != "" {
					fmt.Println()
					fmt.Println(a.Term.InfoBox(out))
					fmt.Println()
				}
			}
			return nil
		},
	}

	ownershipCmd := &cobra.Command{
		Use:   "ownership",
		Short: "Show module ownership relationships",
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			r := a.Repo
			g := graph.Build(r.Result, r.Parsed)

			switch graphFormat(format) {
			case formatMermaid:
				fmt.Println(g.RenderMermaid())
			case formatDOT:
				fmt.Println(g.RenderDOT())
			default:
				out := g.RenderOwnership(a.Term)
				if out != "" {
					fmt.Println()
					fmt.Println(a.Term.InfoBox(out))
					fmt.Println()
				}
			}
			return nil
		},
	}

	goDepsCmd := &cobra.Command{
		Use:   "go-deps",
		Short: "Show Go package dependency graph",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			root := a.RootDir
			if root == "" {
				root = "."
			}

			gg, err := graph.BuildGoGraph(root)
			if err != nil {
				return fmt.Errorf("building Go graph: %w", err)
			}

			switch graphFormat(format) {
			case formatMermaid:
				fmt.Println(gg.RenderMermaid())
			case formatJSON:
				jsonData, err := gg.ToJSON()
				if err != nil {
					return fmt.Errorf("generating JSON: %w", err)
				}
				fmt.Println(string(jsonData))
			default:
				fmt.Println()
				fmt.Println(t.InfoBox(fmt.Sprintf("Go Module: %s", gg.Module)))
				fmt.Println()

				if len(gg.Packages) == 0 {
					fmt.Println(t.Dim("  No packages found in internal/"))
					fmt.Println()
					return nil
				}

				fmt.Println(t.Section(fmt.Sprintf("Packages (%d)", len(gg.Packages))))
				for _, pkg := range gg.Packages {
					fmt.Printf("  %s (%d file(s))\n", t.Bold(pkg.Path), pkg.Files)
					for _, e := range gg.Edges {
						if e.From == pkg.ImportPath {
							shortTo := e.To
							if len(shortTo) > 60 {
								shortTo = "..." + shortTo[len(shortTo)-57:]
							}
							fmt.Printf("    %s %s\n", t.Dim("→"), t.Dim(shortTo))
						}
					}
				}
				fmt.Println()
			}
			return nil
		},
	}

	cmd.AddCommand(treeCmd, depsCmd, ownershipCmd, goDepsCmd)
	return cmd
}
