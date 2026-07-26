package commands

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

func CmdAI(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "ai",
		Short: "🤖  AI orchestration",
		Long: `Orchestrate work between AI systems (OpenCode and OpenHands).

OpenCode handles interactive tasks: debugging, builds, tests, editing.
OpenHands is a self-hosted AI coding agent available for autonomous tasks.

Commands:
  ai status       Show AI system availability
  ai route <desc> Route a task description to the appropriate AI system`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(
		aiStatus(a),
		aiRoute(a),
	)

	return cmd
}

func aiStatus(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show AI system availability",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println()
			fmt.Println(t.Header("🤖  AI Systems"))
			fmt.Println()

			if a.State != nil {
				comp, ok := a.State.Get("ai")
				if ok {
					fmt.Println(t.KeyValue("State", comp.State.String()))
					fmt.Println(t.KeyValue("Message", comp.Message))
					fmt.Println()
				}
			}

			fmt.Println(t.Section("OpenHands"))
			if _, err := exec.LookPath("openhands"); err == nil {
				fmt.Println(t.Good("  ✓ Available"))
			} else {
				fmt.Println(t.Dim("  ✗ Not available (run 'openhands' after enabling ivali.openhands)"))
			}
			fmt.Println()

			fmt.Println(t.Section("OpenCode"))
			if _, err := os.Stat(".opencode"); err == nil {
				fmt.Println(t.Good("  ✓ OpenCode configured"))
			} else {
				fmt.Println(t.Dim("  ✗ OpenCode not configured"))
			}
			if _, err := os.Stat("opencode/README.md"); err == nil {
				fmt.Println(t.Good("  ✓ Knowledge base available"))
			} else {
				fmt.Println(t.Dim("  ✗ Knowledge base not found"))
			}
			fmt.Println()

			fmt.Println(t.Section("Routing Rules"))
			fmt.Println(t.Dim("  All tasks  →  OpenCode"))
			fmt.Println()

			return nil
		},
	}
}

func aiRoute(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "route <description>",
		Short: "Route a task to the appropriate AI system",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			description := strings.Join(args, " ")
			t := a.Term

			fmt.Println()
			fmt.Println(t.Header("🤖  AI Routing"))
			fmt.Println()
			fmt.Println(t.KeyValue("Task", description))

			system := routeTask(description)
			fmt.Println(t.KeyValue("Routed to", system))

			fmt.Println()

			switch system {
			case "opencode":
				fmt.Println(t.Dim("  OpenCode is your interactive CLI."))
				fmt.Println(t.Dim("  Describe what you need in natural language."))
			}
			fmt.Println()

			return nil
		},
	}
}

func routeTask(description string) string {
	return "opencode"
}
