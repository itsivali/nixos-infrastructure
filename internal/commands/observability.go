package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

func CmdObservability(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "observability",
		Short: "📊  Check observability stack health",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println(t.Header("📊 Observability Health"))
			fmt.Println()

			type svc struct {
				name string
				url  string
			}

			services := []svc{
				{"Prometheus", "http://127.0.0.1:9090/-/healthy"},
				{"Grafana", "http://127.0.0.1:3000/grafana/api/health"},
				{"Loki", "http://127.0.0.1:3100/ready"},
			}

			for _, s := range services {
				out, err := exec.Command("curl", "-sf", "--max-time", "3", s.url).CombinedOutput()
				if err != nil {
					fmt.Printf("  %s %-15s %s\n", t.Bad("✗"), s.name, t.Dim("unavailable"))
				} else {
					resp := strings.TrimSpace(string(out))
					if len(resp) > 50 {
						resp = resp[:50] + "..."
					}
					fmt.Printf("  %s %-15s %s\n", t.Good("✓"), s.name, t.Dim(resp))
				}
			}

			fmt.Println()
			fmt.Println(t.Section("Systemd Services"))
			obsServices := []string{"prometheus", "grafana", "loki", "alloy", "falco", "prometheus-node-exporter"}
			for _, svc := range obsServices {
				out, _ := exec.Command("systemctl", "is-active", svc).CombinedOutput()
				state := strings.TrimSpace(string(out))
				icon := t.Bad("✗")
				if state == "active" {
					icon = t.Good("✓")
				}
				fmt.Printf("  %s %-30s %s\n", icon, svc, state)
			}

			return nil
		},
	}
}
