package commands

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/dashboard"
)

func CmdDashboard(a *app.App) *cobra.Command {
	var theme string

	cmd := &cobra.Command{
		Use:   "dashboard",
		Short: "Launch interactive control center",
		Long: `Launch an interactive terminal UI dashboard that provides a real-time
view of repository health, module overview, and system status.

Controls:
  Tab/S-Tab    Switch panels
  ↑/↓  j/k     Navigate lists
  s            Cycle sort order
  /            Filter modules
  Enter        Toggle module detail
  r            Refresh data
  ?            Toggle help
  q/Ctrl+C     Quit

Requires an interactive terminal.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			if theme != "" {
				a.Term = a.Term.WithTheme(theme)
			}

			m := dashboard.New(a.Repo, a.Term)
			p := tea.NewProgram(m, tea.WithAltScreen())

			if _, err := p.Run(); err != nil {
				fmt.Fprintln(os.Stderr, a.Term.Bad("Dashboard error: ")+err.Error())
				return nil
			}

			return nil
		},
	}

	cmd.Flags().StringVarP(&theme, "theme", "t", "", "Theme: auto, light, or dark")
	return cmd
}
