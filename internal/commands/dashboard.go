package commands

import (
	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdDashboard(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "dashboard",
		Short: "Launch interactive control center",
		Long:  `Launch an interactive terminal UI dashboard showing repository health, git status, module overview, suggestions, and quick actions.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return nil
		},
	}
}
