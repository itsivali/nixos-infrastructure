package commands

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

func confirmAction(t *terminal.Terminal, message string) bool {
	if !terminal.IsInteractive() {
		return true
	}
	fmt.Printf("  %s %s %s ",
		t.ColoredIcon("", t.Color.Yellow),
		message,
		t.Dim("[y/N]"))
	var response string
	fmt.Scanln(&response)
	response = strings.TrimSpace(strings.ToLower(response))
	return response == "y" || response == "yes"
}

func runWithTimer(t *terminal.Terminal, desc string, fn func() error) error {
	start := time.Now()
	fmt.Printf("  %s %s\n",
		t.ColoredIcon("", t.Color.Cyan),
		desc)

	err := fn()

	elapsed := time.Since(start)
	mins := int(elapsed.Minutes())
	secs := int(elapsed.Seconds()) % 60
	timing := fmt.Sprintf("%dm%ds", mins, secs)

	fmt.Print("\033[1A\033[K")
	if err != nil {
		fmt.Printf("  %s %s  %s\n",
			t.ColoredIcon("", t.Color.Red),
			desc,
			t.Dim(timing))
	} else {
		fmt.Printf("  %s %s  %s\n",
			t.ColoredIcon("", t.Color.Green),
			desc,
			t.Dim(timing))
	}
	return err
}

func runSilent(t *terminal.Terminal, desc, cmdName string, args ...string) error {
	return runWithTimer(t, desc, func() error {
		c := exec.Command(cmdName, args...)
		return c.Run()
	})
}

func runWithOutput(t *terminal.Terminal, desc, cmdName string, args ...string) error {
	return runWithTimer(t, desc, func() error {
		c := exec.Command(cmdName, args...)
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		return c.Run()
	})
}
