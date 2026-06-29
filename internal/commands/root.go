package commands

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/repository"
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
			if verbose {
				a.Log.Debug().Msg("verbose mode enabled")
			}
			_ = jsonOutput
			return nil
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			repo, found := repository.Detect(".")
			if !found {
				fmt.Println(a.Term.RenderSplash())
				return nil
			}

			_ = repo
			return cmd.Help()
		},
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	root.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")
	root.PersistentFlags().BoolVarP(&jsonOutput, "json", "j", false, "JSON output")

	root.SetHelpTemplate(helpTemplate(a))

	root.AddCommand(
		CmdDashboard(a),
		CmdDoctor(a),
		CmdStatus(a),
		CmdBootstrap(a),
	)

	return root
}

func helpTemplate(a *app.App) string {
	return func() string {
		var b strings.Builder

		b.WriteString(a.Term.Splash("IVALI"))
		b.WriteString(" — " + a.Term.Dim("NixOS Infrastructure Control Plane") + "\n\n")

		categories := []category{
			{Name: "Repository Commands", Commands: []string{
				"dashboard    Launch interactive control center",
				"status       Show repository state summary",
				"doctor       Run all health checks",
				"verify       Full verification (lint + health + architecture)",
				"graph        Display module/import/ownership graphs",
				"explain      Explain a module or option",
				"suggest      Analyze and recommend improvements",
			}},
			{Name: "Operations", Commands: []string{
				"update       Pull latest + update flake inputs",
				"rebuild      nixos-rebuild switch",
				"deploy       Deploy to host",
				"reconcile    Trigger GitOps reconciliation",
			}},
			{Name: "Bootstrap", Commands: []string{
				"bootstrap shell      Generate shell module",
				"bootstrap editor     Generate editor module",
				"bootstrap service    Generate service module",
				"bootstrap package    Generate package set",
				"bootstrap module     Generate NixOS domain module",
			}},
			{Name: "Extract", Commands: []string{
				"extract shell        Extract config into shell module",
				"extract git          Extract config into git module",
				"extract environment  Extract config into environment module",
			}},
			{Name: "Utilities", Commands: []string{
				"docs         Generate documentation",
				"help         Help about any command",
			}},
		}

		for _, cat := range categories {
			b.WriteString(a.Term.Section(cat.Name) + "\n")
			for _, line := range cat.Commands {
				parts := strings.SplitN(line, " ", 2)
				cmd := parts[0]
				desc := ""
				if len(parts) > 1 {
					desc = parts[1]
				}
				b.WriteString("  " + a.Term.HelpCommand(cmd, desc) + "\n")
			}
			b.WriteString("\n")
		}

		b.WriteString(a.Term.Section("Flags") + "\n")
		b.WriteString("  " + a.Term.HelpCommand("-h, --help", "Show help") + "\n")
		b.WriteString("  " + a.Term.HelpCommand("-v, --verbose", "Verbose output") + "\n")
		b.WriteString("  " + a.Term.HelpCommand("-j, --json", "JSON output") + "\n")
		b.WriteString("\n")
		b.WriteString(a.Term.Dim("Run 'ivali <command> --help' for more detail.") + "\n")

		return b.String()
	}()
}
