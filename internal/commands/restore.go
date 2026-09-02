package commands

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

func CmdRestore(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "restore",
		Short: "🔄  Restore from restic backup",
	}

	cmd.AddCommand(&cobra.Command{
		Use:   "list",
		Short: "📋  List available snapshots",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			env := os.Environ()
			env = append(env, "RESTIC_PASSWORD_FILE=/run/secrets/restic_password", "RESTIC_REPOSITORY=/mnt/backup")
			c := exec.Command("restic", "snapshots")
			c.Env = env
			out, err := c.CombinedOutput()
			if err != nil {
				fmt.Println(t.Bad("Failed to list snapshots"))
				fmt.Println(t.Dim(string(out)))
				return nil
			}
			fmt.Println(t.Section("🔄 Available Snapshots"))
			fmt.Println(t.Dim(string(out)))
			return nil
		},
	})

	cmd.AddCommand(&cobra.Command{
		Use:   "latest",
		Short: "▶  Restore from latest snapshot",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			if !confirmAction(t, "Restore from latest backup snapshot?") {
				return nil
			}
			fmt.Println(t.Dim("Restoring from latest snapshot..."))
			env := os.Environ()
			env = append(env, "RESTIC_PASSWORD_FILE=/run/secrets/restic_password", "RESTIC_REPOSITORY=/mnt/backup")
			c := exec.Command("restic", "restore", "latest", "--target", "/")
			c.Env = env
			out, err := c.CombinedOutput()
			if err != nil {
				return fmt.Errorf("restore failed: %s\n%s", err, string(out))
			}
			fmt.Println(t.Good("✓ Restore completed"))
			return nil
		},
	})

	return cmd
}
