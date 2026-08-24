package commands

import (
	"encoding/json"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

func CmdAudit(a *app.App) *cobra.Command {
	var limit int
	var action string

	cmd := &cobra.Command{
		Use:   "audit",
		Short: "Show audit log of operational actions",
		Long: `Display the audit log recording all operational actions including
deployments, rollbacks, service restarts, and other system changes.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			logger := operations.NewAuditLogger()
			entries, err := logger.Query(cmd.Context(), limit, action)
			if err != nil {
				return fmt.Errorf("query audit log: %w", err)
			}

			if a.JSONOutput {
				data, _ := json.MarshalIndent(entries, "", "  ")
				fmt.Println(string(data))
				return nil
			}

			fmt.Println()
			fmt.Println(t.Section("Audit Log"))
			fmt.Println()

			if len(entries) == 0 {
				fmt.Println(t.Dim("  No audit entries found"))
				fmt.Println()
				return nil
			}

			for _, entry := range entries {
				timeStr := entry.Timestamp.Format("2006-01-02 15:04:05")
				status := t.Good("✓")
				if entry.Result == "failed" {
					status = t.Bad("✗")
				} else if entry.Result == "skipped" {
					status = t.Warn("○")
				}

				fmt.Printf("  %s %s  %s → %s",
					status,
					t.Dim(timeStr),
					entry.Action,
					entry.Target)
				if entry.Actor != "" {
					fmt.Printf("  (%s)", t.Dim(entry.Actor))
				}
				fmt.Println()

				if entry.Error != "" {
					fmt.Printf("      %s %s\n", t.Bad("Error:"), entry.Error)
				}
			}
			fmt.Println()

			return nil
		},
	}

	cmd.Flags().IntVarP(&limit, "limit", "n", 20, "Maximum number of entries to show")
	cmd.Flags().StringVarP(&action, "action", "a", "", "Filter by action type (deploy, rollback, restart)")

	return cmd
}
