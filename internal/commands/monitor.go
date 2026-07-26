package commands

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

type MonitorSnapshot struct {
	Timestamp string        `json:"timestamp"`
	Disk      string        `json:"disk"`
	Memory    string        `json:"memory"`
	CPU       CPUSnapshot   `json:"cpu"`
	Services  []ServiceInfo `json:"services"`
}

type CPUSnapshot struct {
	Load  string `json:"load"`
	Cores string `json:"cores"`
}

type ServiceInfo struct {
	Name   string `json:"name"`
	Status string `json:"status"`
	Active bool   `json:"active"`
}

func CmdMonitor(a *app.App) *cobra.Command {
	var interval int
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "monitor",
		Short: "🖥️  Watch real-time system metrics",
		Long:  `Display disk, memory, CPU, and service status at regular intervals.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			if jsonOutput {
				return runMonitorJSON(interval)
			}

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
	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output as JSON (single snapshot)")
	return cmd
}

func runMonitorJSON(interval int) error {
	snapshot := MonitorSnapshot{
		Timestamp: time.Now().Format(time.RFC3339),
		Disk:      runMonitorCmd("df -h / /nix/store 2>/dev/null | tail -n +2"),
		Memory:    runMonitorCmd("free -h | grep Mem"),
		CPU: CPUSnapshot{
			Load:  strings.TrimSpace(runMonitorCmd("cat /proc/loadavg")),
			Cores: strings.TrimSpace(runMonitorCmd("nproc")),
		},
	}

	services := []string{"NetworkManager", "sshd", "tailscaled", "grafana", "prometheus", "loki", "ivali-bot"}
	snapshot.Services = make([]ServiceInfo, len(services))
	for i, svc := range services {
		out, err := exec.Command("systemctl", "is-active", svc).CombinedOutput()
		status := strings.TrimSpace(string(out))
		if err != nil {
			status = "inactive"
		}
		snapshot.Services[i] = ServiceInfo{
			Name:   svc,
			Status: status,
			Active: status == "active",
		}
	}

	data, err := json.MarshalIndent(snapshot, "", "  ")
	if err != nil {
		return fmt.Errorf(" marshaling JSON: %w", err)
	}
	fmt.Println(string(data))
	return nil
}

func runMonitorCmd(cmd string) string {
	out, err := exec.Command("sh", "-c", cmd).CombinedOutput()
	if err != nil {
		return "unavailable"
	}
	return strings.TrimSpace(string(out))
}
