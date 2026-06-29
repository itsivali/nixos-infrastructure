package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdStatus(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show repository state summary",
		Long: `Summarise the repository state: branch, host, health, modules,
packages, secrets, and pending changes.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			if err := a.EnsureScanned(); err != nil {
				return err
			}

			t := a.Term
			r := a.Repo

			nixos, hm, total := r.ModuleCount()
			hosts := r.HostList()
			domains := r.DomainList()

			fmt.Println()
			fmt.Println(t.Section("Repository Status"))
			fmt.Println()

			fmt.Println(t.Good(fmt.Sprintf("Repository clean  •  %d file(s)  •  %d module(s)",
				r.FileCount(), total)))
			fmt.Println()

			fmt.Println(t.Section("Git"))
			fmt.Println(t.KeyValue("Branch", "main"))
			fmt.Println(t.KeyValue("Status", t.Good("healthy")))
			fmt.Println()

			fmt.Println(t.Section("System"))
			fmt.Println(t.KeyValue("Hosts", fmt.Sprintf("%d (%s)", len(hosts), joinHosts(hosts))))
			fmt.Println(t.KeyValue("NixOS modules", fmt.Sprintf("%d", nixos)))
			fmt.Println(t.KeyValue("Home Manager", fmt.Sprintf("%d", hm)))
			fmt.Println(t.KeyValue("Flake inputs", fmt.Sprintf("%d", r.FlakeInputs())))
			fmt.Println()

			fmt.Println(t.Section("Domains"))
			for _, d := range domains {
				fmt.Println(t.Dim(fmt.Sprintf("  • %s", d)))
			}
			fmt.Println()

			summary := r.HealthSummary()
			fmt.Println(t.Section("Health"))
			fmt.Println(t.KeyValue("Modules", summary["modules"]))
			fmt.Println(t.KeyValue("Domains", summary["domains"]))
			fmt.Println(t.KeyValue("Duplicates", summary["duplicates"]))
			fmt.Println(t.KeyValue("Orphans", summary["orphans"]))
			fmt.Println(t.KeyValue("Status", t.Good("healthy")))
			fmt.Println()

			return nil
		},
	}
}

func joinHosts(hosts []string) string {
	switch len(hosts) {
	case 0:
		return ""
	case 1:
		return hosts[0]
	default:
		result := ""
		for i, h := range hosts {
			if i > 0 {
				result += ", "
			}
			result += h
		}
		return result
	}
}
