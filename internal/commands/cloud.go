package commands

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

// CmdCloud manages cloud/file-sync integrations (OneDrive, …).
// Status and setup commands shell out to the declaratively installed
// tools (`onedrive` CLI / `systemctl --user`), layered with user-facing
// diagnostics.
func CmdCloud(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "cloud",
		Short: "☁️  Cloud file sync integrations (OneDrive)",
		Long: `Manage cloud file-sync integrations.

Subcommands:
  onedrive status   OneDrive sync status + service health
  onedrive setup    OneDrive first-run authorization + sync
  onedrive sync     OneDrive one-shot synchronize (--single-directory)`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(cmdCloudOneDrive(a))
	return cmd
}

func cmdCloudOneDrive(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "onedrive",
		Short: "OneDrive file sync",
		Long: `OneDrive synchronization via the open-source onedrive client.

State is owned by the Home Manager module (home/cloud/onedrive.nix);
this command reports on it and drives one-off operations.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "status",
			Short: "OneDrive sync status + service health",
			RunE: func(c *cobra.Command, args []string) error {
				t := a.Term
				fmt.Println(t.Section("OneDrive"))

				if out, err := exec.Command("systemctl", "--user", "status", "onedrive.service").CombinedOutput(); err != nil {
					fmt.Println(t.Dim("service: not running"))
					_ = out
				} else {
					first := strings.SplitN(string(out), "\n", 2)[0]
					fmt.Println(t.KeyValue("Service", strings.TrimSpace(first)))
				}

				home, _ := os.UserHomeDir()
				cfg := fmt.Sprintf("%s/.config/onedrive/config", home)
				if _, err := os.Stat(cfg); err == nil {
					fmt.Println(t.KeyValue("Config", "configured"))
				} else {
					fmt.Println(t.Bad("Config missing — run: ivali cloud onedrive setup"))
				}

				if out, err := exec.Command("onedrive", "--display-sync-status").CombinedOutput(); err == nil {
					fmt.Print(string(out))
				} else {
					fmt.Println(t.Dim("sync status unavailable (not authorized yet)"))
					fmt.Println(t.Dim("  run: ivali cloud onedrive setup"))
				}
				return nil
			},
		},
		&cobra.Command{
			Use:   "setup",
			Short: "OneDrive first-run authorization + sync",
			RunE: func(c *cobra.Command, args []string) error {
				t := a.Term
				fmt.Println(t.Section("OneDrive Setup"))
				fmt.Println("A browser will open for Microsoft SSO authorization.")
				fmt.Println("Complete the login, then the sync service starts automatically.")

				if out, err := exec.Command("onedrive", "--monitor").CombinedOutput(); err != nil {
					fmt.Println(t.Bad("authorization/sync failed"))
					fmt.Println(strings.TrimSpace(string(out)))
					return err
				}
				fmt.Println(t.Good("OneDrive authorized and synchronizing."))
				return nil
			},
		},
		&cobra.Command{
			Use:   "sync",
			Short: "OneDrive one-shot synchronization",
			RunE: func(c *cobra.Command, args []string) error {
				t := a.Term
				if out, err := exec.Command("onedrive", "--synchronize").CombinedOutput(); err != nil {
					fmt.Println(t.Bad("synchronization failed"))
					fmt.Println(strings.TrimSpace(string(out)))
					return err
				}
				fmt.Println(t.Good("OneDrive synchronized."))
				return nil
			},
		},
	)

	return cmd
}
