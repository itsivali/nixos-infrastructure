package commands

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

type MetricsReport struct {
	Timestamp   time.Time         `json:"timestamp"`
	Repository  MetricsRepository `json:"repository"`
	Modules     MetricsModules    `json:"modules"`
	Health      MetricsHealth     `json:"health"`
	Documentation MetricsDoc      `json:"documentation"`
}

type MetricsRepository struct {
	Root        string `json:"root"`
	TotalFiles  int    `json:"total_files"`
	TotalLines  int    `json:"total_lines"`
	Domains     int    `json:"domains"`
	Hosts       int    `json:"hosts"`
	Packages    int    `json:"packages"`
	FlakeInputs int    `json:"flake_inputs"`
}

type MetricsModules struct {
	NixOS   int `json:"nixos"`
	HomeMgr int `json:"home_manager"`
	Total   int `json:"total"`
}

type MetricsHealth struct {
	Duplicates     int `json:"duplicates"`
	Orphans        int `json:"orphans"`
	MissingDocs    int `json:"missing_docs"`
	Score          int `json:"score"`
}

type MetricsDoc struct {
	TotalModules   int     `json:"total_modules"`
	Documented     int     `json:"documented"`
	MissingHeaders int     `json:"missing_headers"`
	CoveragePercent float64 `json:"coverage_percent"`
}

func CmdMetrics(a *app.App) *cobra.Command {
	var outputJSON bool
	var outputFile string

	cmd := &cobra.Command{
		Use:   "metrics",
		Short: "Generate repository metrics report",
		Long: `Generate a comprehensive metrics report for the repository including:
  - Repository statistics (files, lines, domains, hosts)
  - Module counts (NixOS, Home Manager)
  - Health indicators (duplicates, orphans, missing docs)
  - Documentation coverage

Use --json for JSON output.
Use --output to write to a file.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			if err := a.EnsureScanned(); err != nil {
				return err
			}

			r := a.Repo

			// Collect metrics
			nixosCount, hmCount, totalCount := r.ModuleCount()
			dups := r.CheckDuplicateImports()
			orphans := r.CheckOrphanModules()
			missingDocs := r.CheckMissingDocHeaders()
			domains := r.DomainList()
			hosts := r.HostList()

			// Calculate health score
			good := totalCount - len(dups) - len(orphans) - len(missingDocs)
			if good < 0 {
				good = 0
			}
			score := 0
			if totalCount > 0 {
				score = (good * 100) / totalCount
			}

			// Documentation coverage
			documented := totalCount - len(missingDocs)
			coverage := 0.0
			if totalCount > 0 {
				coverage = (float64(documented) / float64(totalCount)) * 100
			}

			report := MetricsReport{
				Timestamp: time.Now(),
				Repository: MetricsRepository{
					Root:        r.Root,
					TotalFiles:  r.FileCount(),
					Domains:     len(domains),
					Hosts:       len(hosts),
					Packages:    r.PackageCount(),
					FlakeInputs: r.FlakeInputs(),
				},
				Modules: MetricsModules{
					NixOS:   nixosCount,
					HomeMgr: hmCount,
					Total:   totalCount,
				},
				Health: MetricsHealth{
					Duplicates:  len(dups),
					Orphans:     len(orphans),
					MissingDocs: len(missingDocs),
					Score:       score,
				},
				Documentation: MetricsDoc{
					TotalModules:    totalCount,
					Documented:      documented,
					MissingHeaders:  len(missingDocs),
					CoveragePercent: coverage,
				},
			}

			// Output
			if outputJSON {
				data, err := json.MarshalIndent(report, "", "  ")
				if err != nil {
					return fmt.Errorf("marshal metrics: %w", err)
				}
				if outputFile != "" {
					if err := os.WriteFile(outputFile, data, 0644); err != nil {
						return fmt.Errorf("write metrics file: %w", err)
					}
					fmt.Printf("Metrics written to %s\n", outputFile)
				} else {
					fmt.Println(string(data))
				}
				return nil
			}

			// Human-readable output
			t := a.Term
			fmt.Println()
			fmt.Println(t.Section("Repository Metrics"))
			fmt.Println()

			fmt.Println(t.Subsection("Repository"))
			fmt.Printf("  Root: %s\n", t.Dim(report.Repository.Root))
			fmt.Printf("  Files: %d\n", report.Repository.TotalFiles)
			fmt.Printf("  Domains: %d\n", report.Repository.Domains)
			fmt.Printf("  Hosts: %d\n", report.Repository.Hosts)
			fmt.Printf("  Packages: %d\n", report.Repository.Packages)
			fmt.Printf("  Flake Inputs: %d\n", report.Repository.FlakeInputs)
			fmt.Println()

			fmt.Println(t.Subsection("Modules"))
			fmt.Printf("  NixOS: %d\n", report.Modules.NixOS)
			fmt.Printf("  Home Manager: %d\n", report.Modules.HomeMgr)
			fmt.Printf("  Total: %d\n", report.Modules.Total)
			fmt.Println()

			fmt.Println(t.Subsection("Health"))
			fmt.Printf("  Score: %d%%\n", report.Health.Score)
			fmt.Printf("  Duplicates: %d\n", report.Health.Duplicates)
			fmt.Printf("  Orphans: %d\n", report.Health.Orphans)
			fmt.Printf("  Missing Docs: %d\n", report.Health.MissingDocs)
			fmt.Println()

			fmt.Println(t.Subsection("Documentation"))
			fmt.Printf("  Documented: %d/%d\n", report.Documentation.Documented, report.Documentation.TotalModules)
			fmt.Printf("  Coverage: %.1f%%\n", report.Documentation.CoveragePercent)
			fmt.Println()

			return nil
		},
	}

	cmd.Flags().BoolVar(&outputJSON, "json", false, "Output as JSON")
	cmd.Flags().StringVarP(&outputFile, "output", "o", "", "Write output to file")

	return cmd
}

// writeMetricsToOpencode writes metrics to opencode/metrics.json for tracking
func writeMetricsToOpencode(root string, report MetricsReport) error {
	opencodeDir := filepath.Join(root, "opencode")
	if err := os.MkdirAll(opencodeDir, 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(filepath.Join(opencodeDir, "metrics.json"), data, 0644)
}
