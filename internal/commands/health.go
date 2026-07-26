package commands

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/repository"
	"github.com/itsivali/nixos-infrastructure/internal/state"
	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

func CmdHealth(a *app.App) *cobra.Command {
	var watch bool
	var system bool

	cmd := &cobra.Command{
		Use:   "health",
		Short: "Show repository and system health summary",
		Long: `Display a health summary of the repository including:
  - Module integrity
  - Duplicate imports
  - Orphan modules
  - Documentation coverage

Use --watch to continuously monitor health status (refreshes every 3s).
Use --system to show system health (disk, memory, CPU, services, Tailscale).`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			if system {
				if watch {
					return runSystemWatch(t)
				}
				renderSystemHealthFromState(t, a)
				return nil
			}

			if !a.RequireRepo() {
				return nil
			}

			if err := a.EnsureScanned(); err != nil {
				return err
			}

			r := a.Repo

			if watch {
				return runHealthWatch(t, r)
			}

			renderHealth(t, r)
			return nil
		},
	}

	cmd.Flags().BoolVarP(&watch, "watch", "w", false, "Watch for changes (live monitoring)")
	cmd.Flags().BoolVar(&system, "system", false, "Show system health only (disk, memory, CPU, services, Tailscale)")
	return cmd
}

func renderHealth(t *terminal.Terminal, r *repository.Repository) {
	dups := r.CheckDuplicateImports()
	orphans := r.CheckOrphanModules()
	missing := r.CheckMissingDocHeaders()
	nixos, hm, total := r.ModuleCount()

	good := total - len(dups) - len(orphans) - len(missing)
	if good < 0 {
		good = 0
	}

	fmt.Println()
	fmt.Println(t.Section("Health Summary"))
	fmt.Println()

	fmt.Println(t.HealthBar(good, len(missing), len(dups)+len(orphans)))
	fmt.Println()

	fmt.Println(t.Subsection("Module Integrity"))
	fmt.Printf("  %s Modules: %d NixOS + %d HM = %d\n\n",
		t.ColoredIcon("", t.Color.Purple), nixos, hm, total)

	fmt.Println(t.Subsection("Duplicate Imports"))
	if len(dups) == 0 {
		fmt.Println(t.Good("None found"))
	} else {
		for _, d := range dups {
			fmt.Printf("  %s %s\n", t.ColoredIcon("", t.Color.Red), t.Dim(d))
		}
	}
	fmt.Println()

	fmt.Println(t.Subsection("Orphan Modules"))
	if len(orphans) == 0 {
		fmt.Println(t.Good("None found"))
	} else {
		for _, o := range orphans {
			fmt.Printf("  %s %s\n", t.ColoredIcon("", t.Color.Yellow), t.Dim(o))
		}
	}
	fmt.Println()

	fmt.Println(t.Subsection("Documentation"))
	if len(missing) == 0 {
		fmt.Println(t.Good("All documented"))
	} else {
		for _, d := range missing {
			fmt.Printf("  %s %s\n", t.ColoredIcon("", t.Color.Yellow), t.Dim(d))
		}
	}
	fmt.Println()
}

func runSystemWatch(t *terminal.Terminal) error {
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	fmt.Print("\033[?25l")
	defer fmt.Print("\033[?25h")

	renderSystemHealth(t)
	fmt.Println("  " + t.Dim(" Watching... refresh every 3s  (Ctrl+C to stop)"))

	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-sigCh:
			fmt.Println()
			fmt.Println("  " + t.Dim("Stopped"))
			fmt.Println()
			return nil
		case <-ticker.C:
			fmt.Print("\033[2J\033[H")
			renderSystemHealth(t)
			fmt.Println("  " + t.Dim(" Watching... refresh every 3s  (Ctrl+C to stop)"))
		}
	}
}

func renderSystemHealthFromState(t *terminal.Terminal, a *app.App) {
	fmt.Println()
	fmt.Println(t.Section("Platform Health"))
	fmt.Println()

	if a.State == nil {
		renderSystemHealth(t)
		return
	}

	globalState := a.State.GlobalState()
	fmt.Println(t.KeyValue("Global State", globalState.String()))
	fmt.Println(t.KeyValue("Components", a.State.Summary()))
	fmt.Println()

	for name, comp := range a.State.All() {
		icon := "✓"
		status := t.Good
		switch comp.State {
		case state.StateWarning:
			icon = "⚠"
			status = t.Warn
		case state.StateDegraded:
			icon = "✗"
			status = t.Bad
		case state.StateOffline:
			icon = "✗"
			status = t.Bad
		case state.StateUnknown:
			icon = "?"
			status = t.Dim
		}
		label := comp.DisplayName
		if label == "" {
			label = name
		}
		fmt.Printf("  %s %s\n", status(fmt.Sprintf("%s %s", icon, label)), t.Dim(comp.Message))
	}
	fmt.Println()

	fmt.Println(t.Subsection("Legacy System Health"))
	fmt.Println()
	for _, c := range systemHealthChecks() {
		fmt.Println(t.CheckList([]terminal.CheckItem{c}))
	}
	fmt.Println()
}

func renderSystemHealth(t *terminal.Terminal) {
	fmt.Println()
	fmt.Println(t.Section("System Health"))
	fmt.Println()
	for _, c := range systemHealthChecks() {
		fmt.Println(t.CheckList([]terminal.CheckItem{c}))
	}
	fmt.Println()
}

func runHealthWatch(t *terminal.Terminal, r *repository.Repository) error {
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	fmt.Print("\033[?25l")
	defer fmt.Print("\033[?25h")

	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()

	renderHealth(t, r)
	fmt.Println("  " + t.Dim(" Watching... refresh every 3s  (Ctrl+C to stop)"))

	for {
		select {
		case <-sigCh:
			fmt.Println()
			fmt.Println("  " + t.Dim("Stopped"))
			fmt.Println()
			return nil
		case <-ticker.C:
			_ = r.EnsureScanned()
			fmt.Print("\033[2J\033[H")
			renderHealth(t, r)
			fmt.Println("  " + t.Dim(" Watching... refresh every 3s  (Ctrl+C to stop)"))
		}
	}
}
