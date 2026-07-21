package commands

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdScan(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "scan",
		Short: "Force re-scan the repository",
		Long: `Force a fresh scan of the repository, bypassing the
disk cache. Useful after making changes to the repository
or the parser.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			t := a.Term

			fmt.Println()
			fmt.Println(t.Section("Scan"))
			fmt.Println()

			fmt.Println("  " + t.Dim("Clearing cache and re-scanning..."))
			a.Repo.ClearCache()
			if err := a.Repo.Scan(); err != nil {
				fmt.Println("  " + t.Warn("Scan failed: "+err.Error()))
				fmt.Println()
				return nil
			}

			nixos, hm, total := a.Repo.ModuleCount()
			hosts := a.Repo.HostList()
			domains := a.Repo.DomainList()

			fmt.Printf("  %s %s\n", t.Info("✔"), t.Dim(fmt.Sprintf("%d modules (%d NixOS + %d HM), %d domains, %d hosts",
				total, nixos, hm, len(domains), len(hosts))))
			fmt.Println()

			return nil
		},
	}
}
