package commands

import (
	"context"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

func CmdRebuild(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "rebuild",
		Short: "Rebuild and activate the current system",
		Long: `Build and activate a new configuration on the local system.
Routes through the operations deployment engine.

This is equivalent to: ivali deploy (with no commit argument)`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			t := a.Term

			fmt.Println()
			fmt.Println(t.Section("Rebuild"))
			fmt.Println()

			label := "Rebuilding system"

			if !confirmAction(t, label+"?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			// Create deployment service
			audit := operations.NewAuditLogger()
			deploy := operations.NewDeploymentService(a.Repo.Root, audit)

			return runWithTimer(t, label, func() error {
				record, err := deploy.Deploy(context.Background(), operations.DeployOpts{
					Actor:  "ivali-cli",
					Source: "cli",
				})
				if err != nil {
					return fmt.Errorf("rebuild failed: %w", err)
				}

				fmt.Printf("  %s %s\n", t.Dim("Status:"), t.Code(record.Status))
				fmt.Printf("  %s %s\n", t.Dim("Generation:"), t.Code(fmt.Sprintf("%d", record.Generation)))
				fmt.Printf("  %s %s\n", t.Dim("Duration:"), t.Code(record.Duration))
				return nil
			})
		},
	}
}
