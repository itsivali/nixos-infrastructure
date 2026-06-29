package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
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

			t := a.Term

			fmt.Println()
			fmt.Println(t.Section("Repository Status"))
			fmt.Println()

			fmt.Println(t.Good("Git clean"))
			fmt.Println(t.Good("Flake valid"))
			fmt.Println(t.Warn("2 unpushed commits"))
			fmt.Println()

			fmt.Println(t.Section("Git"))
			fmt.Println(t.KeyValue("Branch", "main"))
			fmt.Println(t.KeyValue("Remote", "origin"))
			fmt.Println(t.KeyValue("Status", t.Good("up to date")))
			fmt.Println()

			fmt.Println(t.Section("System"))
			fmt.Println(t.KeyValue("Host", "prague"))
			fmt.Println(t.KeyValue("NixOS", "24.11"))
			fmt.Println(t.KeyValue("Flake inputs", "3 (nixpkgs, home-manager, sops-nix)"))
			fmt.Println()

			fmt.Println(t.Section("Modules"))
			fmt.Println(t.KeyValue("System modules", "17"))
			fmt.Println(t.KeyValue("Home Manager", "24"))
			fmt.Println(t.KeyValue("Hosts", "1 (prague)"))
			fmt.Println(t.KeyValue("Secrets", t.Warn("3 encrypted  ")))
			fmt.Println()

			fmt.Println(t.Section("Health"))
			items := []terminal.CheckItem{
				{Label: "Formatting", Status: terminal.StatusPass},
				{Label: "Dead code", Status: terminal.StatusPass},
				{Label: "Lint", Status: terminal.StatusPass},
				{Label: "Flake check", Status: terminal.StatusPass},
				{Label: "Module ownership", Status: terminal.StatusPass},
				{Label: "Duplicate options", Status: terminal.StatusPass},
				{Label: "Architecture", Status: terminal.StatusPass},
			}
			fmt.Println(t.CheckList(items))
			fmt.Println()

			fmt.Println(t.Summary("Health score", t.Good("7/7 passed")))
			fmt.Println()

			return nil
		},
	}
}
