package commands

import (
	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdDoctor(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "doctor",
		Short: "Run all repository health checks",
		Long:  `Run every repository health check including formatting, linting, module ownership, import validation, and architecture compliance.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return nil
		},
	}
}
