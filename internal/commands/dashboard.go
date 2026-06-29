package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdDashboard(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "dashboard",
		Short: "Launch interactive control center",
		Long: `Launch an interactive terminal UI dashboard that provides a real-time
view of repository health, git status, module overview, system status,
suggestions, and quick actions — all in a keyboard-driven interface.

Requires an interactive terminal.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			fmt.Println(a.Term.Warn("Dashboard TUI not yet implemented"))
			fmt.Println(a.Term.Dim("  Coming in Phase 5: an interactive Bubbletea dashboard."))
			fmt.Println()

			return nil
		},
	}
}
