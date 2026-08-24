package commands

import (
	"context"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

func CmdRollback(a *app.App) *cobra.Command {
	var generation int

	cmd := &cobra.Command{
		Use:   "rollback",
		Short: "Roll back to a previous NixOS generation",
		Long: `Activate a previous NixOS system generation.

Without --generation, rolls back to the previous generation.
With --generation <N>, activates that specific generation.

Routes through the operations deployment engine.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			t := a.Term

			fmt.Println()
			fmt.Println(t.Section("Rollback"))
			fmt.Println()

			var target string
			if generation > 0 {
				target = fmt.Sprintf("generation %d", generation)
			} else {
				target = "previous generation"
			}

			if !confirmAction(t, "Roll back to "+target+"?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			// Create deployment service
			audit := operations.NewAuditLogger()
			deploy := operations.NewDeploymentService(a.Repo.Root, audit)

			return runWithTimer(t, "Rolling back", func() error {
				result, err := deploy.Rollback(context.Background(), operations.RollbackOpts{
					Generation: generation,
					Actor:      "ivali-cli",
					Reason:     "manual rollback via CLI",
				})
				if err != nil {
					return fmt.Errorf("rollback failed: %w", err)
				}

				if result.Success {
					fmt.Printf("  %s %s\n", t.Dim("Status:"), t.Code("success"))
				} else {
					fmt.Printf("  %s %s\n", t.Dim("Status:"), t.Code("failed"))
					if result.Error != "" {
						fmt.Printf("  %s %s\n", t.Dim("Error:"), t.Code(result.Error))
					}
				}
				fmt.Printf("  %s %s → %s\n", t.Dim("Generation:"), t.Code(fmt.Sprintf("%d", result.FromGen)), t.Code(fmt.Sprintf("%d", result.ToGen)))
				fmt.Printf("  %s %v\n", t.Dim("Health:"), t.Code(fmt.Sprintf("%v", result.HealthPassed)))
				return nil
			})
		},
	}

	cmd.Flags().IntVarP(&generation, "generation", "g", 0, "Target generation to rollback to (0 = previous)")

	return cmd
}
