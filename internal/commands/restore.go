package commands

import (
	"fmt"
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
			out, err := exec.Command("sh", "-c", "RESTIC_PASSWORD_FILE=/run/secrets/restic_password RESTIC_REPOSITORY=/mnt/backup restic snapshots 2>&1").CombinedOutput()
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
			out, err := exec.Command("sh", "-c", "RESTIC_PASSWORD_FILE=/run/secrets/restic_password RESTIC_REPOSITORY=/mnt/backup restic restore latest --target / 2>&1").CombinedOutput()
			if err != nil {
				return fmt.Errorf("restore failed: %s\n%s", err, string(out))
			}
			fmt.Println(t.Good("✓ Restore completed"))
			return nil
		},
	})

	return cmd
}
