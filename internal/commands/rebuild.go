package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdRebuild(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "rebuild [host]",
		Short: "Run nixos-rebuild switch",
		Long: `Build and activate a new configuration on the target host.
If no host is specified, builds the current system.

Runs: sudo nixos-rebuild switch --flake .#<host>`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			t := a.Term
			root := a.Repo.Root

			host := ""
			if len(args) > 0 {
				host = args[0]
			}

			fmt.Println()
			fmt.Println(t.Section("Rebuild"))
			fmt.Println()

			rebuildArgs := []string{"nixos-rebuild", "switch", "--flake", root}
			if host != "" {
				rebuildArgs[len(rebuildArgs)-1] = root + "#" + host
			}

			label := "Rebuilding system"
			if host != "" {
				label += " (" + host + ")"
			}

			if !confirmAction(t, label+"?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			return runWithOutput(t, label, "sudo", rebuildArgs...)
		},
	}
}
