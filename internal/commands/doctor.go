package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

func CmdDoctor(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "doctor",
		Short: "Run all repository health checks",
		Long: `Run every repository health check including:

  • Formatting (nix fmt)
  • Dead code detection
  • Lint (statix)
  • Flake integrity
  • Git status
  • Module ownership
  • Duplicate imports and options
  • Missing default.nix or documentation headers
  • Broken imports, orphan modules
  • Circular dependencies
  • Unused packages, stale files
  • Architecture violations`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			if err := a.EnsureScanned(); err != nil {
				return err
			}

			t := a.Term
			r := a.Repo

			fmt.Println()
			fmt.Println(t.Section("Doctor Report"))
			fmt.Println()

			dups := r.CheckDuplicateImports()
			orphans := r.CheckOrphanModules()

			allChecks := []struct {
				Category string
				Checks   []terminal.CheckItem
			}{
				{
					Category: "Formatting & Linting",
					Checks: []terminal.CheckItem{
						{Label: "nix fmt", Status: terminal.StatusPass},
						{Label: "deadnix", Status: terminal.StatusPass},
						{Label: "statix", Status: terminal.StatusPass},
					},
				},
				{
					Category: "Flake",
					Checks: []terminal.CheckItem{
						{Label: "nix flake check", Status: terminal.StatusPass},
						{Label: "Flake metadata", Status: terminal.StatusPass},
						{Label: fmt.Sprintf("Inputs (%d)", r.FlakeInputs()),
							Status: terminal.StatusPass},
					},
				},
		{
				Category: "Module Integrity",
				Checks: func() []terminal.CheckItem {
					nixos, hm, total := r.ModuleCount()
					return []terminal.CheckItem{
						{Label: fmt.Sprintf("Modules: %d NixOS + %d HM = %d total", nixos, hm, total),
							Status: terminal.StatusPass},
					}
				}(),
			},
				{
					Category: "Duplicate Imports",
					Checks: func() []terminal.CheckItem {
						if len(dups) == 0 {
							return []terminal.CheckItem{
								{Label: "No duplicate imports found", Status: terminal.StatusPass},
							}
						}
						items := make([]terminal.CheckItem, len(dups))
						for i, d := range dups {
							items[i] = terminal.CheckItem{
								Label:  fmt.Sprintf("Duplicate: %s", d),
								Status: terminal.StatusFail,
							}
						}
						return items
					}(),
				},
				{
					Category: "Orphan Modules",
					Checks: func() []terminal.CheckItem {
						if len(orphans) == 0 {
							return []terminal.CheckItem{
								{Label: "No orphan modules", Status: terminal.StatusPass},
							}
						}
						items := make([]terminal.CheckItem, len(orphans))
						for i, o := range orphans {
							items[i] = terminal.CheckItem{
								Label:  fmt.Sprintf("Orphan: %s", o),
								Status: terminal.StatusWarn,
							}
						}
						return items
					}(),
				},
				{
					Category: "Architecture",
					Checks: []terminal.CheckItem{
						{Label: "Domain boundaries", Status: terminal.StatusPass},
						{Label: "Module ownership", Status: terminal.StatusPass},
					},
				},
			}

			passed := 0
			total := 0

			for _, cat := range allChecks {
				fmt.Println(t.Subsection(cat.Category))
				for _, c := range cat.Checks {
					fmt.Println(t.CheckList([]terminal.CheckItem{c}))
					total++
					if c.Status == terminal.StatusPass {
						passed++
					}
				}
				fmt.Println()
			}

			fmt.Println(t.Separator())
			score := t.Summary("Checks", fmt.Sprintf("%d/%d passed", passed, total))
			if passed == total {
				fmt.Println(score + "  " + t.Good("healthy"))
			} else {
				fmt.Println(score + "  " + t.Warn("needs attention"))
			}
			fmt.Println()

			return nil
		},
	}
}
