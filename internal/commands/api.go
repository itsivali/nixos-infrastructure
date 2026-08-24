package commands

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/api"
	"github.com/itsivali/nixos-infrastructure/internal/app"
)

func CmdAPI(a *app.App) *cobra.Command {
	var addr string

	cmd := &cobra.Command{
		Use:   "api",
		Short: "Start the operations API server",
		Long: `Start the internal operations API server providing typed HTTP endpoints
for health, deployments, services, drift detection, and audit.

This server is intended to be run as a systemd service and accessed
via Tailscale Serve.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			repoDir := a.RootDir
			if repoDir == "" {
				repoDir = "/home/ivali/nixos-infrastructure"
			}

			cfg := api.Config{
				Addr:    addr,
				RepoDir: repoDir,
			}

			server := api.NewServer(cfg)
			if err := server.Start(); err != nil {
				return fmt.Errorf("api server failed: %w", err)
			}
			return nil
		},
	}

	cmd.Flags().StringVar(&addr, "addr", "127.0.0.1:8080", "Address to listen on")

	return cmd
}

func init() {
	// Register the api command when the app is created
	// This is called from root.go
}
