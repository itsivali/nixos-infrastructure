package commands

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdDeploy(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "deploy <host>",
		Short: "Deploy configuration to a target host",
		Long: `Deploy the current configuration to a remote host using
nixos-rebuild with --target-host.

Runs: nixos-rebuild switch --flake .#<host> --target-host <host>`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			t := a.Term
			root := a.Repo.Root
			host := args[0]

			fmt.Println()
			fmt.Println(t.Section("Deploy"))
			fmt.Println()

			fmt.Printf("  %s %s\n", t.Dim("Target:"), t.Code(host))
			fmt.Println()

			c := exec.Command("nixos-rebuild", "switch",
				"--flake", root+"#"+host,
				"--target-host", host,
			)
			c.Stdout = os.Stdout
			c.Stderr = os.Stderr
			if err := c.Run(); err != nil {
				fmt.Println()
				fmt.Println("  " + t.Warn("Deploy failed"))
				fmt.Println()
				return nil
			}

			fmt.Println()
			fmt.Println("  " + t.Good("Deployed to " + host))
			fmt.Println()
			return nil
		},
	}
}
