package commands

import (
	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdStatus(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show repository state summary",
		Long:  `Summarise the repository state: branch, health, modules, packages, and pending changes.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			a.Term.Section("Repository Status")

			return nil
		},
	}
}
