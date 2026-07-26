package commands

import (
	"fmt"
	"time"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/state"
	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

func CmdRemediation(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "remediation",
		Short: "Manage auto-remediation engine",
		Long:  `View and control the auto-remediation engine that fixes detected issues.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if a.Remediation == nil {
				fmt.Println("Remediation engine not initialized")
				return nil
			}

			t := a.Term
			fmt.Println()
			fmt.Println(t.Section("Remediation Engine"))
			fmt.Println()

			fmt.Println(t.KeyValue("Actions", fmt.Sprintf("%d registered", a.Remediation.ActionCount())))
			history := a.Remediation.HistoryLast(10)
			if len(history) > 0 {
				fmt.Println()
				fmt.Println(t.Subsection("Recent Actions"))
				for _, h := range history {
					status := "✓"
					if h.Result == nil || !h.Result.Success {
						status = "✗"
					}
					fmt.Printf("  %s %s → %s (%s)\n",
						t.Dim(h.Timestamp.Format("15:04:05")),
						t.Bold(h.Action),
						t.Dim(h.Component),
						status)
				}
			}
			fmt.Println()
			return nil
		},
	}

	startCmd := &cobra.Command{
		Use:   "start",
		Short: "Start the remediation engine",
		RunE: func(cmd *cobra.Command, args []string) error {
			if a.Remediation == nil {
				fmt.Println("Remediation engine not initialized")
				return nil
			}
			a.Remediation.Start()
			fmt.Println("Remediation engine started")
			return nil
		},
	}

	stopCmd := &cobra.Command{
		Use:   "stop",
		Short: "Stop the remediation engine",
		RunE: func(cmd *cobra.Command, args []string) error {
			if a.Remediation == nil {
				fmt.Println("Remediation engine not initialized")
				return nil
			}
			a.Remediation.Stop()
			fmt.Println("Remediation engine stopped")
			return nil
		},
	}

	cmd.AddCommand(startCmd, stopCmd)
	return cmd
}

func CmdHealthMonitor(a *app.App) *cobra.Command {
	var watch bool

	cmd := &cobra.Command{
		Use:   "health-monitor",
		Short: "System health monitoring service",
		Long:  `Monitor system health (disk, memory, load, services) and auto-fix issues.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if a.Monitor == nil {
				fmt.Println("Health monitor not initialized")
				return nil
			}

			t := a.Term

			if watch {
				a.Monitor.Start()
				defer a.Monitor.Stop()

				fmt.Println(t.Header("Health Monitor"))
				fmt.Println(t.Dim("  Monitoring every 30s  •  Press Ctrl+C to stop"))
				fmt.Println()

				ticker := time.NewTicker(30 * time.Second)
				defer ticker.Stop()

				for {
					renderHealthMonitorStatus(t, a)
					<-ticker.C
					fmt.Print("\033[2J\033[H")
				}
			}

			renderHealthMonitorStatus(t, a)
			return nil
		},
	}

	cmd.Flags().BoolVarP(&watch, "watch", "w", false, "Watch health status continuously")
	return cmd
}

func renderHealthMonitorStatus(t *terminal.Terminal, a *app.App) {
	fmt.Println()
	fmt.Println(t.Section("Health Monitor"))
	fmt.Println()

	if a.State == nil {
		fmt.Println(t.Dim("  State engine not initialized"))
		return
	}

	fmt.Println(t.KeyValue("Global State", a.State.GlobalState().String()))
	fmt.Println(t.KeyValue("Components", a.State.Summary()))
	fmt.Println()

	for name, comp := range a.State.All() {
		if comp.State == state.StateUnknown {
			continue
		}
		icon := "✓"
		status := t.Good
		switch comp.State {
		case state.StateWarning:
			icon = "⚠"
			status = t.Warn
		case state.StateDegraded, state.StateOffline:
			icon = "✗"
			status = t.Bad
		}
		label := comp.DisplayName
		if label == "" {
			label = name
		}
		fmt.Printf("  %s %s\n", status(fmt.Sprintf("%s %s", icon, label)), t.Dim(comp.Message))
	}
	fmt.Println()
}
