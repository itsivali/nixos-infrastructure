package commands

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

// CmdDiff runs a dry NixOS rebuild and prints the derivations that would
// change versus the current system. It is a fast pre-deploy sanity check.
func CmdDiff(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "diff",
		Short: "Show what a rebuild would change (dry build)",
		Long: `Run a dry NixOS rebuild and print the derivations that would
change vs the current system. Useful as a pre-deploy sanity check and as
the local half of the canary gate.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			t := a.Term
			host, _ := os.Hostname()
			target := fmt.Sprintf("%s/#%s", a.Repo.Root, host)

			fmt.Println()
			fmt.Println(t.Section("Rebuild Diff (dry)"))
			fmt.Println()

			out, err := exec.Command("nixos-rebuild", "dry-build", "--flake", target).CombinedOutput()
			if err != nil {
				fmt.Println(t.Bad("dry-build failed"))
				fmt.Println(string(out))
				return nil
			}
			fmt.Println(string(out))
			return nil
		},
	}
}
