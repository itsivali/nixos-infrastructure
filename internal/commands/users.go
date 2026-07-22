package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdUsers(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "users",
		Short: "👤  Show system users and groups",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println(t.Header("👤 System Users"))
			fmt.Println()

			out, err := exec.Command("getent", "passwd").CombinedOutput()
			if err != nil {
				fmt.Println(t.Bad("Failed to list users"))
				return nil
			}

			fmt.Println(t.Section("Human Users (UID ≥ 1000)"))
			for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
				parts := strings.Split(line, ":")
				if len(parts) >= 7 {
					uid := parts[2]
					if uid >= "1000" {
						fmt.Println(t.Dim(fmt.Sprintf("  • %-15s  uid=%-6s  home=%-20s  shell=%s",
							parts[0], uid, parts[5], parts[6])))
					}
				}
			}
			fmt.Println()

			groups, err := exec.Command("getent", "group").CombinedOutput()
			if err == nil {
				fmt.Println(t.Section("Groups"))
				for _, line := range strings.Split(strings.TrimSpace(string(groups)), "\n") {
					parts := strings.Split(line, ":")
					if len(parts) >= 4 && strings.Contains(parts[3], "ivali") {
						fmt.Println(t.Dim(fmt.Sprintf("  • %s (members: %s)", parts[0], parts[3])))
					}
				}
			}
			fmt.Println()

			sudo, _ := exec.Command("sh", "-c", "sudo -n true 2>&1 && echo 'passwordless' || echo 'requires password'").CombinedOutput()
			fmt.Println(t.Section("Sudo Access"))
			fmt.Println(t.KeyValue("Current user", strings.TrimSpace(string(sudo))))

			return nil
		},
	}
}
