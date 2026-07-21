package commands

import (
	"fmt"
	"sort"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdSuggest(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "suggest",
		Short: "Analyze repository and recommend improvements",
		Long: `Analyze the repository structure and provide actionable
recommendations for improvement, including:

  • Orphan modules that should be integrated or removed
  • Duplicate imports across modules
  • Modules without documentation headers
  • Modules declaring options (potential API surface)
  • Architecture and organization suggestions`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			t := a.Term
			r := a.Repo

			fmt.Println()
			fmt.Println(t.Section("Improvement Suggestions"))
			fmt.Println()

			orphans := r.CheckOrphanModules()
			dups := r.CheckDuplicateImports()
			missingHeaders := r.CheckMissingDocHeaders()
			optMods := r.CheckModulesWithOptions()

			suggestions := []struct {
				Severity string
				Title    string
				Items    []string
			}{}

			if len(orphans) > 0 {
				suggestions = append(suggestions, struct {
					Severity string
					Title    string
					Items    []string
				}{
					Severity: "warning",
					Title:    fmt.Sprintf("Orphan Modules (%d)", len(orphans)),
					Items:    orphans,
				})
			}

			if len(dups) > 0 {
				suggestions = append(suggestions, struct {
					Severity string
					Title    string
					Items    []string
				}{
					Severity: "warning",
					Title:    fmt.Sprintf("Duplicate Imports (%d)", len(dups)),
					Items:    dups,
				})
			}

			if len(missingHeaders) > 0 {
				display := missingHeaders
				if len(display) > 10 {
					display = display[:10]
				}
				suggestions = append(suggestions, struct {
					Severity string
					Title    string
					Items    []string
				}{
					Severity: "info",
					Title:    fmt.Sprintf("Modules Missing Doc Headers (%d)", len(missingHeaders)),
					Items:    display,
				})
			}

			if len(optMods) > 0 {
				display := optMods
				if len(display) > 10 {
					display = display[:10]
				}
				suggestions = append(suggestions, struct {
					Severity string
					Title    string
					Items    []string
				}{
					Severity: "info",
					Title:    fmt.Sprintf("Modules Declaring Options (%d)", len(optMods)),
					Items:    display,
				})
			}

			if len(suggestions) == 0 {
				fmt.Println(t.Good("  No suggestions — repository is in excellent shape!"))
				fmt.Println()
				return nil
			}

			sort.Slice(suggestions, func(i, j int) bool {
				return suggestions[i].Title < suggestions[j].Title
			})

			for _, s := range suggestions {
				var severityStyle string
				switch s.Severity {
				case "warning":
					severityStyle = t.Warn("!")
				default:
					severityStyle = t.Info("i")
				}

				fmt.Printf("  %s  %s\n", severityStyle, t.Bold(s.Title))

				maxItems := 5
				for i, item := range s.Items {
					if i >= maxItems {
						remaining := len(s.Items) - maxItems
						fmt.Printf("    %s  (+ %d more)\n", t.Dim("→"), remaining)
						break
					}
					fmt.Printf("    %s  %s\n", t.Dim("→"), t.Dim(item))
				}
				fmt.Println()
			}

			totalIssues := len(orphans) + len(dups) + len(missingHeaders)
			fmt.Println(t.Separator())
			summary := t.Summary("Suggestions", fmt.Sprintf("%d items across %d categories", totalIssues, len(suggestions)))
			if totalIssues == 0 {
				fmt.Println(summary + "  " + t.Good("clean"))
			} else {
				fmt.Println(summary + "  " + t.Warn(fmt.Sprintf("%d improvement(s) available", totalIssues)))
			}
			fmt.Println()

			return nil
		},
	}
}
