package commands

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

type category struct {
	Name     string
	Commands []string
}

func Root(a *app.App) *cobra.Command {
	var verbose bool
	var jsonOutput bool

	root := &cobra.Command{
		Use:   "ivali",
		Short: "IVALI — NixOS Infrastructure Control Plane",
		Long: `IVALI is the control plane for a modular NixOS infrastructure repository.

It understands the repository, monitors it, validates it, automates
repetitive work, generates modules, assists development, and provides
a beautiful interactive terminal experience.`,
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			a.SetVerbose(verbose)
			a.SetJSON(jsonOutput)
			return nil
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			if a.HasRepo() {
				return cmd.Help()
			}

			fmt.Println(a.Term.RenderSplash())
			return nil
		},
		SilenceUsage: false,
		SilenceErrors: false,
	}

	root.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")
	root.PersistentFlags().BoolVarP(&jsonOutput, "json", "j", false, "JSON output")

	root.SetHelpTemplate(rootHelp(a))

	root.AddCommand(
		CmdBootstrap(a),
		CmdDashboard(a),
		CmdDeploy(a),
		CmdDoctor(a),
		CmdDocs(a),
		CmdExplain(a),
		CmdExtract(a),
		CmdGraph(a),
		CmdHealth(a),
		CmdMetrics(a),
		CmdRebuild(a),
		CmdReconcile(a),
		CmdScan(a),
		CmdStatus(a),
		CmdSuggest(a),
		CmdUpdate(a),
		CmdVerify(a),
	)

	return root
}

func splitCommandLine(line string) [2]string {
	parts := strings.Fields(line)
	if len(parts) == 0 {
		return [2]string{"", ""}
	}
	if len(parts) == 1 {
		return [2]string{parts[0], ""}
	}
	cmd := parts[0]
	rest := ""
	for i, p := range parts[1:] {
		if i > 0 {
			rest += " "
		}
		rest += p
	}
	return [2]string{cmd, rest}
}

func rootHelp(a *app.App) string {
	t := a.Term

	groups := []struct {
		Title    string
		Commands []string
	}{
		{
			Title: "Repository Commands",
			Commands: []string{
				"dashboard       Launch interactive control center",
				"status          Show repository state summary",
				"doctor          Run all repository health checks",
				"verify          Full verification (lint, health, architecture)",
				"graph           Display module and dependency graphs",
				"explain         Explain a module or option",
				"suggest         Analyze repository and recommend improvements",
			},
		},
		{
			Title: "Operations",
			Commands: []string{
				"update          Pull latest changes and update flake inputs",
				"rebuild         Run nixos-rebuild switch",
				"deploy          Deploy to target host",
				"reconcile       Trigger GitOps reconciliation loop",
			},
		},
		{
			Title: "Bootstrap Generators",
			Commands: []string{
				"bootstrap module    Generate a NixOS domain module",
				"bootstrap service   Generate a service module",
				"bootstrap shell     Generate a shell module structure",
				"bootstrap editor    Generate an editor module",
				"bootstrap package   Generate a package set",
				"bootstrap host      Generate a new laptop host configuration",
			},
		},
		{
			Title: "Extract Commands",
			Commands: []string{
				"extract shell        Extract config into shell module",
				"extract git          Extract config into git module",
				"extract environment  Extract config into environment module",
			},
		},
		{
			Title: "Utilities",
			Commands: []string{
				"docs            Generate project documentation",
				"metrics         Generate repository metrics report",
				"help            Display help for any command",
			},
		},
	}

	var b strings.Builder

	b.WriteString("  " + t.Header("IVALI") + t.Dim("  —  NixOS Infrastructure Control Plane") + "\n\n")

	for _, g := range groups {
		b.WriteString(t.Section(g.Title) + "\n")
		for _, line := range g.Commands {
			parts := splitCommandLine(line)
			b.WriteString(t.HelpCommand(parts[0], parts[1]) + "\n")
		}
		b.WriteString("\n")
	}

	b.WriteString(t.Section("Global Flags") + "\n")
	b.WriteString(t.HelpCommand("-h, --help", "Show help for any command") + "\n")
	b.WriteString(t.HelpCommand("-v, --verbose", "Enable verbose output") + "\n")
	b.WriteString(t.HelpCommand("-j, --json", "Output in JSON format") + "\n")
	b.WriteString("\n")
	b.WriteString(t.Dim("  Use ivali <command> --help  for detailed information.") + "\n")

	return b.String()
}
