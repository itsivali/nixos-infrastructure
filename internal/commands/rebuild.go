package commands

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

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

			fmt.Println("  " + t.Dim("Running: sudo "+strings.Join(rebuildArgs, " ")))
			fmt.Println()

			c := exec.Command("sudo", rebuildArgs...)
			c.Stdout = os.Stdout
			c.Stderr = os.Stderr
			if err := c.Run(); err != nil {
				fmt.Println()
				fmt.Println("  " + t.Warn("Rebuild failed"))
				fmt.Println()
				return nil
			}

			fmt.Println()
			fmt.Println("  " + t.Good("Rebuild complete"))
			fmt.Println()
			return nil
		},
	}
}
