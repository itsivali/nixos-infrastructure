package commands

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

func CmdJules(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "jules",
		Short: "🤖  Google Jules AI coding agent",
		Long:  `Manage Google Jules tasks, sessions, and configuration.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(
		julesStatus(a),
		julesLogin(a),
		julesTask(a),
		julesTasks(a),
		julesCancel(a),
		julesHistory(a),
		julesLogs(a),
		julesConfig(a),
	)

	return cmd
}

func julesStatus(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show Jules connection and auth status",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println(t.Header("🤖  Jules Status"))
			fmt.Println()

			// Check if jules binary is available
			if _, err := exec.LookPath("jules"); err != nil {
				fmt.Println(t.Bad("  Jules CLI not found in PATH"))
				fmt.Println(t.Dim("  Install with: nixos-rebuild switch --flake .#prague"))
				return nil
			}

			fmt.Println(t.Good("  ✓ Jules CLI installed"))

			// Check API key
			apiKey := os.Getenv("JULES_API_KEY")
			if apiKey == "" {
				// Try reading from SOPS secret
				if data, err := os.ReadFile("/run/secrets/jules-api-key"); err == nil {
					apiKey = strings.TrimSpace(string(data))
				}
			}

			if apiKey != "" {
				fmt.Println(t.Good("  ✓ API key configured"))
			} else {
				fmt.Println(t.Bad("  ✗ API key not found"))
				fmt.Println(t.Dim("  Run: ivali jules login"))
			}

			// Check if authenticated
			out, err := exec.Command("jules", "remote", "list").CombinedOutput()
			if err == nil && strings.TrimSpace(string(out)) != "" {
				fmt.Println(t.Good("  ✓ Authenticated"))
			} else {
				fmt.Println(t.Dim("  ℹ Not authenticated"))
				fmt.Println(t.Dim("    1. Run: jules login  (browser OAuth with Google)"))
				fmt.Println(t.Dim("    2. Install: https://github.com/apps/google-labs-jules/installations/select_target"))
			}

			return nil
		},
	}
}

func julesLogin(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "login",
		Short: "Authenticate with Google Jules",
		Long: `Authenticate with Google Jules via browser OAuth flow.
This opens a browser window for Google account selection.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println(t.Header("🔐  Jules Login"))
			fmt.Println()
			fmt.Println(t.Dim("  After login, also install the GitHub app:"))
			fmt.Println(t.Dim("  https://github.com/apps/google-labs-jules/installations/select_target"))
			fmt.Println()

			if !confirmAction(t, "Open browser for Jules authentication?") {
				fmt.Println(t.Dim("  Cancelled."))
				return nil
			}

			return runWithOutput(t, "Authenticating with Jules...", "jules", "login")
		},
	}
}

func julesTask(a *app.App) *cobra.Command {
	var description string

	cmd := &cobra.Command{
		Use:   "task [task-id]",
		Short: "Show task details or create a new task",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			if description != "" {
				// Create a new task
				fmt.Println(t.Header("🤖  Creating Jules Task"))
				fmt.Println()
				return runWithOutput(t, "Submitting task...", "jules", "new", "--description", description)
			}

			if len(args) == 0 {
				return fmt.Errorf("provide a task ID or use --description to create a new task")
			}

			// Show task details
			fmt.Println(t.Header(fmt.Sprintf("📋  Jules Task: %s", args[0])))
			fmt.Println()
			return runWithOutput(t, "Fetching task details...", "jules", "task", args[0])
		},
	}

	cmd.Flags().StringVarP(&description, "description", "d", "", "Description for a new task")
	return cmd
}

func julesTasks(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "tasks",
		Short: "List all Jules tasks",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println(t.Header("📋  Jules Tasks"))
			fmt.Println()
			return runWithOutput(t, "Listing tasks...", "jules", "tasks")
		},
	}
}

func julesCancel(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "cancel [task-id]",
		Short: "Cancel a running Jules task",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println(t.Header(fmt.Sprintf("🚫  Cancelling Jules Task: %s", args[0])))
			fmt.Println()

			if !confirmAction(t, fmt.Sprintf("Cancel task %s?", args[0])) {
				fmt.Println(t.Dim("  Cancelled."))
				return nil
			}

			return runWithOutput(t, "Cancelling task...", "jules", "cancel", args[0])
		},
	}
}

func julesHistory(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "history",
		Short: "Show completed Jules tasks",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println(t.Header("📜  Jules History"))
			fmt.Println()
			return runWithOutput(t, "Fetching history...", "jules", "history")
		},
	}
}

func julesLogs(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "logs [task-id]",
		Short: "Show Jules task logs",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println(t.Header(fmt.Sprintf("📝  Jules Logs: %s", args[0])))
			fmt.Println()
			return runWithOutput(t, "Fetching logs...", "jules", "logs", args[0])
		},
	}
}

func julesConfig(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "config",
		Short: "Show or set Jules configuration",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println(t.Header("⚙️   Jules Configuration"))
			fmt.Println()

			configDir := os.Getenv("JULES_CONFIG_DIR")
			if configDir == "" {
				configDir = "$HOME/.config/jules"
			}
			fmt.Println(t.KeyValue("Config dir", configDir))

			apiKey := os.Getenv("JULES_API_KEY")
			if apiKey != "" {
				fmt.Println(t.KeyValue("API key", "(from environment)"))
			} else if _, err := os.ReadFile("/run/secrets/jules-api-key"); err == nil {
				fmt.Println(t.KeyValue("API key", "(from SOPS secret)"))
			} else {
				fmt.Println(t.KeyValue("API key", t.Dim("not configured")))
			}

			return nil
		},
	}
}
