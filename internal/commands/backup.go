package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdBackup(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "backup",
		Short: "💾  Manage restic backups",
	}

	cmd.AddCommand(&cobra.Command{
		Use:   "run",
		Short: "▶  Trigger a backup now",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			if !confirmAction(t, "Trigger restic backup?") {
				return nil
			}
			fmt.Println(t.Dim("Starting restic backup..."))
			out, err := exec.Command("systemctl", "start", "restic-backup").CombinedOutput()
			if err != nil {
				return fmt.Errorf("backup failed: %s\n%s", err, string(out))
			}
			fmt.Println(t.Good("✓ Backup started successfully"))
			return nil
		},
	})

	cmd.AddCommand(&cobra.Command{
		Use:   "list",
		Short: "📋  List backup snapshots",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			out, err := exec.Command("sh", "-c", "RESTIC_PASSWORD_FILE=/run/secrets/restic_password RESTIC_REPOSITORY=/mnt/backup restic snapshots 2>&1").CombinedOutput()
			if err != nil {
				fmt.Println(t.Bad("Failed to list snapshots"))
				fmt.Println(t.Dim(string(out)))
				return nil
			}
			fmt.Println(t.Section("📦 Backup Snapshots"))
			fmt.Println(t.Dim(string(out)))
			return nil
		},
	})

	cmd.AddCommand(&cobra.Command{
		Use:   "status",
		Short: "📊  Show backup status",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			out, err := exec.Command("sh", "-c", "systemctl show restic-backup --property=ActiveState,LastTriggerUSec,Result 2>&1").CombinedOutput()
			if err != nil {
				fmt.Println(t.Bad("Cannot check backup status"))
				return nil
			}
			fmt.Println(t.Section("💾 Backup Service Status"))
			for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
				parts := strings.SplitN(line, "=", 2)
				if len(parts) == 2 {
					fmt.Println(t.KeyValue(parts[0], parts[1]))
				}
			}
			return nil
		},
	})

	return cmd
}
