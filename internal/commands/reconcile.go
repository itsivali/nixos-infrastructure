package commands

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdReconcile(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "reconcile",
		Short: "Trigger GitOps reconciliation loop",
		Long: `Pull the latest configuration and apply it on the current
system. Runs the update and rebuild steps in sequence.

Runs: git pull --ff-only && nixos-rebuild switch --flake .`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			t := a.Term
			root := a.Repo.Root

			fmt.Println()
			fmt.Println(t.Section("Reconcile"))
			fmt.Println()

			if !confirmAction(t, "Reconcile (pull + rebuild)?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			if err := runSilent(t, "Pulling latest changes", "git", "-C", root, "pull", "--ff-only"); err != nil {
				fmt.Println()
				return nil
			}

			return runWithOutput(t, "Rebuilding system", "sudo", "nixos-rebuild", "switch", "--flake", root)
		},
	}
}
