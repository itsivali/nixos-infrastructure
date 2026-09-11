package commands

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/platform/health"
	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

func CmdDesktop(a *app.App) *cobra.Command {
	var watch bool

	cmd := &cobra.Command{
		Use:   "desktop",
		Short: "GNOME desktop diagnostics and health",
		Long: `Desktop diagnostics for the GNOME workstation.

Subcommands:
  health        Run desktop health checks
  audio         Audio diagnostics (PipeWire/WirePlumber/EasyEffects)`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	healthCmd := &cobra.Command{
		Use:   "health",
		Short: "Run desktop health checks",
		Long:  "Display health status of the GNOME desktop environment and related services.",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println()
			fmt.Println(t.Section("Desktop Health"))
			fmt.Println()

			results := health.RunAllDesktopChecks()
			items := make([]terminal.CheckItem, len(results))
			for i, r := range results {
				items[i] = checkResultToItem(r)
			}
			fmt.Println(t.CheckList(items))
			fmt.Println()

			if watch {
				return runDesktopWatch(t)
			}
			return nil
		},
	}
	healthCmd.Flags().BoolVarP(&watch, "watch", "w", false, "Watch for changes (refresh every 3s)")

	audioCmd := &cobra.Command{
		Use:   "audio",
		Short: "Audio diagnostics (PipeWire / WirePlumber / EasyEffects)",
		Long: `Run the repository audio diagnostic and report on the EasyEffects
volume-boost service and PipeWire state.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term
			fmt.Println(t.Section("Audio Diagnostics"))

			if out, err := exec.Command("audio-diagnostic").CombinedOutput(); err == nil {
				fmt.Print(string(out))
			} else {
				fmt.Println(t.Dim("audio-diagnostic unavailable"))
				fmt.Println(strings.TrimSpace(string(out)))
			}

			if out, err := exec.Command("systemctl", "--user", "status", "easyeffects.service").CombinedOutput(); err == nil {
				first := strings.SplitN(string(out), "\n", 2)[0]
				fmt.Println(t.KeyValue("EasyEffects", strings.TrimSpace(first)))
			} else {
				fmt.Println(t.Dim("EasyEffects service not running (audio boost disabled)"))
			}
			return nil
		},
	}

	cmd.AddCommand(healthCmd, audioCmd)
	return cmd
}

func runDesktopWatch(t *terminal.Terminal) error {
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	fmt.Print("\033[?25l")
	defer fmt.Print("\033[?25h")

	renderDesktopHealth(t)
	fmt.Println("  " + t.Dim("Watching... refresh every 3s  (Ctrl+C to stop)"))

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
			renderDesktopHealth(t)
			fmt.Println("  " + t.Dim("Watching... refresh every 3s  (Ctrl+C to stop)"))
		}
	}
}

func renderDesktopHealth(t *terminal.Terminal) {
	fmt.Println()
	fmt.Println(t.Section("Desktop Health"))
	fmt.Println()
	for _, c := range health.RunAllDesktopChecks() {
		fmt.Println(t.CheckList([]terminal.CheckItem{checkResultToItem(c)}))
	}
	fmt.Println()
}
