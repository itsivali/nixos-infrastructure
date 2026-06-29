package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdUpdate(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "update",
		Short: "Pull latest changes and update flake inputs",
		Long:  `Fetch the latest changes from Git remote and update Nix flake inputs to their latest versions.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			t := a.Term

			fmt.Println()
			fmt.Println(t.Section("Update"))
			fmt.Println()
			fmt.Println(t.Warn("Git operations not yet implemented"))
			fmt.Println(t.Dim("  Will execute: git pull --ff-only && nix flake update"))
			fmt.Println()

			return nil
		},
	}
}
