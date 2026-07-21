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
		Long: `Fetch the latest changes from Git remote and update Nix flake
inputs to their latest versions.

Runs: git pull --ff-only && nix flake update`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			t := a.Term
			root := a.Repo.Root

			fmt.Println()
			fmt.Println(t.Section("Update"))
			fmt.Println()

			if !confirmAction(t, "Update (pull + flake update)?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			if err := runWithOutput(t, "Pulling latest changes", "git", "-C", root, "pull", "--ff-only"); err != nil {
				fmt.Println()
				return nil
			}

			return runWithOutput(t, "Updating flake inputs", "nix", "flake", "update", "--option", "flake-dir", root)
		},
	}
}
