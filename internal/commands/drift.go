package commands

import (
	"encoding/json"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

func CmdDrift(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "drift",
		Short: "Detect configuration drift",
		Long: `Compare desired state (Git HEAD) with actual state (deployed generation,
running services) and report any drift.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			repoDir := a.RootDir

			svc := operations.NewDriftService(repoDir)
			report, err := svc.Detect(cmd.Context())
			if err != nil {
				return fmt.Errorf("drift detection failed: %w", err)
			}

			if a.JSONOutput {
				data, _ := json.MarshalIndent(report, "", "  ")
				fmt.Println(string(data))
				return nil
			}

			fmt.Println()
			fmt.Println(t.Section("Drift Detection"))
			fmt.Println()

			if !report.OverallDrift {
				fmt.Println(t.Good("No drift detected — system is in sync"))
			} else {
				fmt.Println(t.Warn("Drift detected!"))
			}
			fmt.Println()

			fmt.Println(t.KeyValue("Desired Commit", shortSHA(report.GitDesiredCommit)))
			fmt.Println(t.KeyValue("Deployed Commit", shortSHA(report.GitDeployedCommit)))
			if report.GitDrift {
				fmt.Println(t.KeyValue("Git Drift", t.Warn("YES")))
			} else {
				fmt.Println(t.KeyValue("Git Drift", t.Good("No")))
			}
			fmt.Println()

			fmt.Println(t.KeyValue("Expected Generation", fmt.Sprintf("%d", report.GenExpected)))
			fmt.Println(t.KeyValue("Active Generation", fmt.Sprintf("%d", report.GenActive)))
			if report.GenDrift {
				fmt.Println(t.KeyValue("Generation Drift", t.Warn("YES")))
			} else {
				fmt.Println(t.KeyValue("Generation Drift", t.Good("No")))
			}
			fmt.Println()

			if report.ServicesDrift {
				fmt.Println(t.KeyValue("Services Drift", t.Warn(fmt.Sprintf("YES (%d services)", len(report.DriftedServices)))))
				for _, svc := range report.DriftedServices {
					fmt.Printf("  %s %s\n", t.Warn("✗"), svc)
				}
			} else {
				fmt.Println(t.KeyValue("Services Drift", t.Good("No")))
			}
			fmt.Println()

			return nil
		},
	}
}

func shortSHA(sha string) string {
	if len(sha) >= 8 {
		return sha[:8]
	}
	return sha
}
