package commands

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/repository"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

func CmdHealth(a *app.App) *cobra.Command {
	var watch bool

	cmd := &cobra.Command{
		Use:   "health",
		Short: "Show repository health summary",
		Long: `Display a health summary of the repository including:
  - Module integrity
  - Duplicate imports
  - Orphan modules
  - Documentation coverage

Use --watch to continuously monitor health status (refreshes every 3s).`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			if err := a.EnsureScanned(); err != nil {
				return err
			}

			t := a.Term
			r := a.Repo

			if watch {
				return runHealthWatch(t, r)
			}

			renderHealth(t, r)
			return nil
		},
	}

	cmd.Flags().BoolVarP(&watch, "watch", "w", false, "Watch for changes (live monitoring)")
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
			r.EnsureScanned()
			fmt.Print("\033[2J\033[H")
			renderHealth(t, r)
			fmt.Println("  " + t.Dim(" Watching... refresh every 3s  (Ctrl+C to stop)"))
		}
	}
}
