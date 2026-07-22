package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdServices(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "services",
		Short: "⚙️  Show systemd service status",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println(t.Header("⚙️  Service Status"))
			fmt.Println()

			services := []string{
				"NetworkManager", "sshd", "tailscaled",
				"grafana", "prometheus", "loki", "alloy", "falco",
				"ivali-bot", "restic-backup", "fail2ban",
			}

			fmt.Println(t.Section("Key Services"))
			for _, svc := range services {
				state, _ := exec.Command("systemctl", "is-active", svc).CombinedOutput()
				stateStr := strings.TrimSpace(string(state))

				mem, _ := exec.Command("sh", "-c",
					fmt.Sprintf("systemctl show %s --property=MemoryCurrent 2>/dev/null | cut -d= -f2", svc)).CombinedOutput()
				memStr := strings.TrimSpace(string(mem))

				uptime, _ := exec.Command("sh", "-c",
					fmt.Sprintf("systemctl show %s --property=ActiveEnterTimestamp 2>/dev/null | cut -d= -f2", svc)).CombinedOutput()
				uptimeStr := strings.TrimSpace(string(uptime))

				icon := t.Bad("✗")
				if stateStr == "active" {
					icon = t.Good("✓")
				}

				detail := stateStr
				if memStr != "[not set]" && memStr != "" {
					detail += fmt.Sprintf("  mem=%s", memStr)
				}
				if uptimeStr != "" && uptimeStr != "[not set]" {
					detail += fmt.Sprintf("  since=%s", uptimeStr)
				}

				fmt.Println(fmt.Sprintf("  %s %-25s %s", icon, svc, t.Dim(detail)))
			}

			fmt.Println()
			failed, _ := exec.Command("sh", "-c", "systemctl list-units --state=failed --no-legend 2>/dev/null | head -10").CombinedOutput()
			failedStr := strings.TrimSpace(string(failed))
			if failedStr != "" {
				fmt.Println(t.Bad("Failed Units:"))
				fmt.Println(t.Dim(failedStr))
			} else {
				fmt.Println(t.Good("No failed units"))
			}

			return nil
		},
	}
}
