package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/graph"
)

func CmdGraph(a *app.App) *cobra.Command {
	var depth int

	cmd := &cobra.Command{
		Use:   "graph",
		Short: "Display module and dependency graphs",
		Long: `Display import hierarchy and dependency relationships
between modules in the repository.

Subcommands:
  tree        Show module import tree
  deps        Show flat dependency list
  ownership   Show module ownership relationships`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	treeCmd := &cobra.Command{
		Use:   "tree",
		Short: "Show module import tree",
		Long: `Render a tree view of module import relationships,
starting from root modules (not imported by anything).`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			r := a.Repo
			g := graph.Build(r.Result, r.Parsed)
			opts := graph.ViewOptions{
				Type:  "tree",
				Depth: depth,
			}
			out := g.RenderTree(a.Term, opts)
			if out != "" {
				fmt.Println()
				fmt.Println(a.Term.InfoBox(out))
				fmt.Println()
			}
			return nil
		},
	}
	treeCmd.Flags().IntVarP(&depth, "depth", "d", 3, "Tree depth limit")

	depsCmd := &cobra.Command{
		Use:   "deps",
		Short: "Show flat dependency list",
		Long: `Display a flat list of dependencies grouped by
source module.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			r := a.Repo
			g := graph.Build(r.Result, r.Parsed)
			out := g.RenderDeps(a.Term)
			if out != "" {
				fmt.Println()
				fmt.Println(a.Term.InfoBox(out))
				fmt.Println()
			}
			return nil
		},
	}

	ownershipCmd := &cobra.Command{
		Use:   "ownership",
		Short: "Show module ownership relationships",
		Long:  `Display which modules own which files, based on Ownership headers in module documentation.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			r := a.Repo
			g := graph.Build(r.Result, r.Parsed)
			out := g.RenderOwnership(a.Term)
			if out != "" {
				fmt.Println()
				fmt.Println(a.Term.InfoBox(out))
				fmt.Println()
			}
			return nil
		},
	}

	cmd.AddCommand(treeCmd, depsCmd, ownershipCmd)

	return cmd
}
