package commands

import (
	"fmt"
	"os/exec"

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

			fmt.Println("  " + t.Dim("Pulling latest changes..."))
			gitCmd := exec.Command("git", "pull", "--ff-only")
			gitCmd.Dir = root
			if err := gitCmd.Run(); err != nil {
				fmt.Println()
				fmt.Println("  " + t.Warn("Git pull failed"))
				fmt.Println()
				return nil
			}
			fmt.Println()

			fmt.Println("  " + t.Dim("Rebuilding system..."))
			rebuildCmd := exec.Command("sudo", "nixos-rebuild", "switch", "--flake", root)
			if err := rebuildCmd.Run(); err != nil {
				fmt.Println()
				fmt.Println("  " + t.Warn("Rebuild failed"))
				fmt.Println()
				return nil
			}

			fmt.Println()
			fmt.Println("  " + t.Good("Reconciliation complete"))
			fmt.Println()
			return nil
		},
	}
}
