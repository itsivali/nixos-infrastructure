package commands

import (
	"context"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

func CmdDeploy(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "deploy [commit]",
		Short: "Deploy configuration to the local system",
		Long: `Deploy the current configuration to the local system using
the operations deployment engine.

If a commit SHA is provided, deploys to that specific commit.
Otherwise, deploys to the latest main branch.

Routes through the same deployment engine as the WebUI and GitOps.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			t := a.Term

			var commit string
			if len(args) > 0 {
				commit = args[0]
			}

			fmt.Println()
			fmt.Println(t.Section("Deploy"))
			fmt.Println()

			if commit != "" {
				fmt.Printf("  %s %s\n", t.Dim("Commit:"), t.Code(commit))
			} else {
				fmt.Printf("  %s %s\n", t.Dim("Target:"), t.Code("latest main"))
			}
			fmt.Println()

			if !confirmAction(t, "Deploy to "+commit+"?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			// Create deployment service
			audit := operations.NewAuditLogger()
			deploy := operations.NewDeploymentService(a.Repo.Root, audit)

			return runWithTimer(t, "Deploying", func() error {
				record, err := deploy.Deploy(context.Background(), operations.DeployOpts{
					Commit: commit,
					Actor:  "ivali-cli",
					Source: "cli",
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
