package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
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
				"operations-web-ui",
				"grafana", "prometheus", "loki", "alloy", "falco",
				"restic-backup", "fail2ban",
			}

			fmt.Println(t.Section("Key Services"))
			for _, svc := range services {
				state, _ := exec.Command("systemctl", "is-active", svc).CombinedOutput()
				stateStr := strings.TrimSpace(string(state))

				mem, _ := exec.Command("systemctl", "show", svc, "--property=MemoryCurrent").CombinedOutput()
				memStr := strings.TrimSpace(string(mem))
				// Cut the "MemoryCurrent=" prefix
				if idx := strings.Index(memStr, "="); idx >= 0 {
					memStr = memStr[idx+1:]
				}

				uptime, _ := exec.Command("systemctl", "show", svc, "--property=ActiveEnterTimestamp").CombinedOutput()
				uptimeStr := strings.TrimSpace(string(uptime))
				if idx := strings.Index(uptimeStr, "="); idx >= 0 {
					uptimeStr = uptimeStr[idx+1:]
				}

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

				fmt.Printf("  %s %-25s %s\n", icon, svc, t.Dim(detail))
			}

			fmt.Println()
			failed, _ := exec.Command("systemctl", "list-units", "--state=failed", "--no-legend").CombinedOutput()
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
