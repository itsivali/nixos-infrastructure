package commands

import (
	"fmt"
	"os"
	"os/exec"

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

			fmt.Println("  " + t.Dim("Pulling latest changes..."))
			gitCmd := exec.Command("git", "pull", "--ff-only")
			gitCmd.Dir = root
			gitCmd.Stdout = os.Stdout
			gitCmd.Stderr = os.Stderr
			if err := gitCmd.Run(); err != nil {
				fmt.Println()
				fmt.Println("  " + t.Warn("Git pull failed"))
				fmt.Println()
				return nil
			}
			fmt.Println()

			fmt.Println("  " + t.Dim("Updating flake inputs..."))
			nixCmd := exec.Command("nix", "flake", "update")
			nixCmd.Dir = root
			nixCmd.Stdout = os.Stdout
			nixCmd.Stderr = os.Stderr
			if err := nixCmd.Run(); err != nil {
				fmt.Println()
				fmt.Println("  " + t.Warn("Flake update failed"))
				fmt.Println()
				return nil
			}
			fmt.Println()

			fmt.Println("  " + t.Good("Update complete"))
			fmt.Println()

			return nil
		},
	}
}
