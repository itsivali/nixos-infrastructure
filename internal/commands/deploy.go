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

			if !confirmAction(t, "Deploy to "+host+"?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			return runWithTimer(t, "Deploying to "+host, func() error {
				c := exec.Command("nixos-rebuild", "switch",
					"--flake", root+"#"+host,
					"--target-host", host,
				)
				c.Stdout = os.Stdout
				c.Stderr = os.Stderr
				return c.Run()
			})
		},
	}
}
