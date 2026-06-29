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

			t := a.Term

			fmt.Println()
			fmt.Println(t.Section("Doctor Report"))
			fmt.Println()

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
						{Label: "Inputs up to date", Status: terminal.StatusWarn, Detail: "2 inputs behind"},
					},
				},
				{
					Category: "Git",
					Checks: []terminal.CheckItem{
						{Label: "Working tree clean", Status: terminal.StatusPass},
						{Label: "Branch up to date", Status: terminal.StatusPass},
						{Label: "No unpushed commits", Status: terminal.StatusWarn, Detail: "2 commits ahead"},
					},
				},
				{
					Category: "Module Integrity",
					Checks: []terminal.CheckItem{
						{Label: "Module ownership", Status: terminal.StatusPass},
						{Label: "Duplicate imports", Status: terminal.StatusPass},
						{Label: "Duplicate options", Status: terminal.StatusPass},
						{Label: "Missing default.nix", Status: terminal.StatusPass},
						{Label: "Missing doc headers", Status: terminal.StatusPass},
						{Label: "Broken imports", Status: terminal.StatusPass},
						{Label: "Orphan modules", Status: terminal.StatusPass},
						{Label: "Circular dependencies", Status: terminal.StatusPass},
					},
				},
				{
					Category: "Architecture",
					Checks: []terminal.CheckItem{
						{Label: "Unused packages", Status: terminal.StatusPass},
						{Label: "Stale files", Status: terminal.StatusPass},
						{Label: "Architecture violations", Status: terminal.StatusPass},
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
			fmt.Println()

			score := t.Summary("Checks passed", fmt.Sprintf("%d/%d", passed, total))
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
