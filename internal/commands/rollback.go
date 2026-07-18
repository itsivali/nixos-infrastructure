package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdRollback(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "rollback",
		Short: "Roll back to the previous NixOS generation",
		Long: `Activate the previous NixOS system generation.

Runs: sudo nixos-rebuild switch --rollback`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			t := a.Term

			fmt.Println()
			fmt.Println(t.Section("Rollback"))
			fmt.Println()

			if !confirmAction(t, "Roll back to the previous generation?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			return runWithOutput(t, "Rolling back system", "sudo", "nixos-rebuild", "switch", "--rollback")
		},
	}
}
