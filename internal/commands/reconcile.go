package commands

import (
	"context"
	"fmt"
	"os/exec"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

func CmdReconcile(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "reconcile",
		Short: "Trigger GitOps reconciliation",
		Long: `Pull the latest configuration and deploy it.
Routes through the operations deployment engine.

This is equivalent to: git pull + ivali deploy`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			t := a.Term
			root := a.Repo.Root

			fmt.Println()
			fmt.Println(t.Section("Reconcile"))
			fmt.Println()

			if !confirmAction(t, "Reconcile (pull + deploy)?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			// Pull latest changes
			fmt.Printf("  %s\n", t.Dim("Pulling latest changes..."))
			pull := exec.Command("git", "-C", root, "pull", "--ff-only")
			if err := pull.Run(); err != nil {
				fmt.Printf("  %s %s\n", t.Dim("Status:"), t.Code("git pull failed"))
				return nil
			}
			fmt.Printf("  %s %s\n", t.Dim("Status:"), t.Code("git pull succeeded"))

			// Create deployment service
			audit := operations.NewAuditLogger()
			deploy := operations.NewDeploymentService(root, audit)

			return runWithTimer(t, "Deploying", func() error {
				record, err := deploy.Deploy(context.Background(), operations.DeployOpts{
					Actor:  "ivali-cli",
					Source: "cli-reconcile",
				})
				if err != nil {
					return fmt.Errorf("deploy failed: %w", err)
				}

				fmt.Printf("  %s %s\n", t.Dim("Status:"), t.Code(record.Status))
				fmt.Printf("  %s %s\n", t.Dim("Generation:"), t.Code(fmt.Sprintf("%d", record.Generation)))
				fmt.Printf("  %s %s\n", t.Dim("Duration:"), t.Code(record.Duration))
				return nil
			})
		},
	}
}
