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
		Long: `Orchestrate work between AI systems (OpenCode and Google Jules).

OpenCode handles interactive tasks: debugging, builds, tests, editing.
Jules handles autonomous tasks: auditing, refactoring, documentation.

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

			fmt.Println(t.Section("Jules"))
			if _, err := exec.LookPath("jules"); err == nil {
				fmt.Println(t.Good("  ✓ CLI installed"))
			} else {
				fmt.Println(t.Dim("  ✗ CLI not installed"))
			}
			apiKey := os.Getenv("JULES_API_KEY")
			if apiKey == "" {
				if data, err := os.ReadFile("/run/secrets/jules-api-key"); err == nil {
					apiKey = strings.TrimSpace(string(data))
				}
			}
			if apiKey != "" {
				fmt.Println(t.Good("  ✓ API key configured"))
			} else {
				fmt.Println(t.Dim("  ✗ API key not configured"))
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
			fmt.Println(t.Dim("  Interactive (debug, build, test, edit)  →  OpenCode"))
			fmt.Println(t.Dim("  Autonomous (audit, refactor, document)  →  Jules"))
			fmt.Println(t.Dim("  Long-running (>200 chars description)   →  Jules"))
			fmt.Println(t.Dim("  General / small                         →  OpenCode"))
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
			case "jules":
				fmt.Println(t.Dim("  Run:  ivali jules task --description \"<description>\""))
				fmt.Println(t.Dim("  Or:   jules new --description \"<description>\""))
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
	lower := strings.ToLower(description)

	julesKeywords := []string{
		"audit", "analyze", "analysis",
		"refactor", "modernize",
		"document", "documentation",
		"architecture",
		"all modules", "every module", "repository-wide",
		"dependency", "impact analysis",
		"root cause",
	}

	for _, kw := range julesKeywords {
		if strings.Contains(lower, kw) {
			return "jules"
		}
	}

	if len(description) > 200 {
		return "jules"
	}

	return "opencode"
}
