package commands

import (
	"fmt"
	"os/exec"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

// CmdLogs prints recent journald errors, or a single service's log when a
// service name is supplied. Thin wrapper so the bot /logs command and the
// CLI share one implementation.
func CmdLogs(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "logs [service]",
		Short: "Show recent journald errors (or one service's log)",
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			t := a.Term
			journalArgs := []string{"-b", "--no-pager"}
			if len(args) > 0 {
				journalArgs = append(journalArgs, "-u", args[0], "-n", "100")
			} else {
				journalArgs = append(journalArgs, "-p", "err", "-n", "100")
			}

			out, err := exec.Command("journalctl", journalArgs...).CombinedOutput()
			if err != nil {
				fmt.Println(t.Bad("journalctl failed"))
				fmt.Println(string(out))
				return nil
			}
			fmt.Print(string(out))
			return nil
		},
	}
}
