package commands

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

func CmdSearch(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "search <query>",
		Short: "🔍  Search repository",
		Long: `Search the repository for modules, packages, commands, scripts,
documentation, tests, and services related to a query.

Examples:
  ivali search firewall
  ivali search tailscale
  ivali search grafana
  ivali search --json rollback`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			query := strings.ToLower(args[0])

			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			r := a.Repo
			t := a.Term

			type match struct {
				Type    string `json:"type"`
				Path    string `json:"path"`
				Context string `json:"context,omitempty"`
			}

			var results []match
			seen := make(map[string]bool)

			scan := r.Result
			if scan == nil {
				fmt.Println(t.Dim("  No scan data available"))
				return nil
			}

			for _, mod := range scan.AllModules {
				if matches(query, mod.RelPath) || matches(query, string(mod.Category)) {
					if seen[mod.RelPath] {
						continue
					}
					seen[mod.RelPath] = true
					desc := string(mod.Category)
					results = append(results, match{
						Type:    fmt.Sprintf("module (%s)", desc),
						Path:    mod.RelPath,
						Context: mod.Path,
					})
				}
			}

			for _, domain := range scan.Domains {
				if matches(query, domain.Name) {
					for _, mod := range domain.Modules {
						if seen[mod.RelPath] {
							continue
						}
						seen[mod.RelPath] = true
						results = append(results, match{
							Type: fmt.Sprintf("domain: %s", domain.Name),
							Path: mod.RelPath,
						})
					}
				}
			}

			for _, mod := range scan.Scripts {
				if matches(query, mod.RelPath) || matches(query, mod.Path) {
					if seen[mod.RelPath] {
						continue
					}
					seen[mod.RelPath] = true
					results = append(results, match{
						Type: "script",
						Path: mod.RelPath,
					})
				}
			}

			for _, mod := range scan.Secrets {
				if matches(query, mod.RelPath) {
					if seen[mod.RelPath] {
						continue
					}
					seen[mod.RelPath] = true
					results = append(results, match{
						Type: "secret",
						Path: mod.RelPath,
					})
				}
			}

			for _, mod := range scan.Tests {
				if matches(query, mod.RelPath) {
					if seen[mod.RelPath] {
						continue
					}
					seen[mod.RelPath] = true
					results = append(results, match{
						Type: "test",
						Path: mod.RelPath,
					})
				}
			}

			if a.JSONOutput {
				return json.NewEncoder(cmd.OutOrStdout()).Encode(results)
			}

			fmt.Println()
			fmt.Println(t.Header(fmt.Sprintf("🔍  Search: %s", args[0])))
			fmt.Println()

			if len(results) == 0 {
				fmt.Println(t.Dim(fmt.Sprintf("  No results found for %q", args[0])))
				fmt.Println()
				return nil
			}

			fmt.Println(t.Dim(fmt.Sprintf("  %d result(s) found\n", len(results))))

			byType := make(map[string][]match)
			for _, m := range results {
				byType[m.Type] = append(byType[m.Type], m)
			}

			typeNames := make([]string, 0, len(byType))
			for k := range byType {
				typeNames = append(typeNames, k)
			}
			sort.Strings(typeNames)

			for _, typeName := range typeNames {
				items := byType[typeName]
				fmt.Println(t.Subsection(fmt.Sprintf("%s (%d)", typeName, len(items))))
				for _, m := range items {
					fmt.Printf("  %s %s\n", t.ColoredIcon("", t.Color.Purple), m.Path)
					if m.Context != "" {
						fmt.Printf("    %s\n", t.Dim(m.Context))
					}
				}
				fmt.Println()
			}

			return nil
		},
	}

	return cmd
}

func matches(query, target string) bool {
	return strings.Contains(strings.ToLower(target), query)
}
