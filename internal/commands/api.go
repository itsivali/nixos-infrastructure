package commands

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/api"
	"github.com/itsivali/nixos-infrastructure/internal/app"
)

func CmdAPI(a *app.App) *cobra.Command {
	var addr string
	var insecure bool

	cmd := &cobra.Command{
		Use:   "api",
		Short: "Start the operations API server",
		Long: `Start the internal operations API server providing typed HTTP endpoints
for health, deployments, services, drift detection, and audit.

This server is intended to be run as a systemd service and accessed
via Tailscale Serve.

Authentication is required by default. Set the API token via:
  - IVALI_API_TOKEN environment variable
  - SOPS secret at /run/secrets/api_token

Use --insecure to disable authentication (development only).`,
		RunE: func(cmd *cobra.Command, args []string) error {
			repoDir := a.RootDir
			if repoDir == "" {
				repoDir = "/home/ivali/nixos-infrastructure"
			}

			// Read API token from environment or SOPS secret
			apiToken := os.Getenv("IVALI_API_TOKEN")
			if apiToken == "" {
				// Try reading from token file (SOPS secret path)
				if tokenFile := os.Getenv("IVALI_API_TOKEN_FILE"); tokenFile != "" {
					if data, err := os.ReadFile(tokenFile); err == nil {
						apiToken = string(data)
						// Trim trailing newline common in SOPS-generated files
						if len(apiToken) > 0 && apiToken[len(apiToken)-1] == '\n' {
							apiToken = apiToken[:len(apiToken)-1]
						}
					}
				}
			}
			if apiToken == "" {
				// Try reading from default SOPS secret path
				if data, err := os.ReadFile("/run/secrets/api_token"); err == nil {
					apiToken = string(data)
					if len(apiToken) > 0 && apiToken[len(apiToken)-1] == '\n' {
						apiToken = apiToken[:len(apiToken)-1]
					}
				}
			}

			cfg := api.Config{
				Addr:     addr,
				RepoDir:  repoDir,
				APIToken: apiToken,
				Insecure: insecure,
			}

			server := api.NewServer(cfg)
			if err := server.Start(); err != nil {
				return fmt.Errorf("api server failed: %w", err)
			}
			return nil
		},
	}

	cmd.Flags().StringVar(&addr, "addr", "127.0.0.1:8080", "Address to listen on")
	cmd.Flags().BoolVar(&insecure, "insecure", false, "Disable authentication (development only)")

	return cmd
}

func init() {
	// Register the api command when the app is created
	// This is called from root.go
}
