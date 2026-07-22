package commands

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdMonitor(a *app.App) *cobra.Command {
	var interval int

	cmd := &cobra.Command{
		Use:   "monitor",
		Short: "🖥️  Watch real-time system metrics",
		Long:  `Display disk, memory, CPU, and service status at regular intervals.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println(t.Header("🖥️  System Monitor"))
			fmt.Println(t.Dim(fmt.Sprintf("  Refreshing every %ds  •  Press Ctrl+C to stop", interval)))
			fmt.Println()

			for {
				fmt.Print("\033[H\033[2J")
				fmt.Println(t.Header("🖥️  System Monitor"))
				fmt.Println(t.Dim("  " + time.Now().Format("2006-01-02 15:04:05")))
				fmt.Println()

				disk := runMonitorCmd("df -h / /nix/store 2>/dev/null | tail -n +2")
				fmt.Println(t.Section("Disk"))
				fmt.Println(t.Dim(disk))

				mem := runMonitorCmd("free -h | grep Mem")
				fmt.Println(t.Section("Memory"))
				fmt.Println(t.Dim(mem))

				load := runMonitorCmd("cat /proc/loadavg")
				cpus := runMonitorCmd("nproc")
				fmt.Println(t.Section("CPU"))
				fmt.Println(t.Dim(fmt.Sprintf("Load: %s  •  Cores: %s", strings.TrimSpace(load), strings.TrimSpace(cpus))))

				services := []string{"NetworkManager", "sshd", "tailscaled", "grafana", "prometheus", "loki", "ivali-bot"}
				fmt.Println(t.Section("Services"))
				for _, svc := range services {
					out, err := exec.Command("systemctl", "is-active", svc).CombinedOutput()
					status := strings.TrimSpace(string(out))
					if err != nil {
						status = "inactive"
					}
					if status == "active" {
						fmt.Println(t.Good(fmt.Sprintf("  ✓ %-25s %s", svc, status)))
					} else {
						fmt.Println(t.Bad(fmt.Sprintf("  ✗ %-25s %s", svc, status)))
					}
				}
				fmt.Println()

				time.Sleep(time.Duration(interval) * time.Second)
			}
		},
	}

	cmd.Flags().IntVarP(&interval, "interval", "i", 5, "Refresh interval in seconds")
	return cmd
}

func runMonitorCmd(cmd string) string {
	out, err := exec.Command("sh", "-c", cmd).CombinedOutput()
	if err != nil {
		return "unavailable"
	}
	return strings.TrimSpace(string(out))
}
