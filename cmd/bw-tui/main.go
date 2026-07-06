package main

import (
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/willisivali/nixos-infrastructure/internal/bitwarden"
)

func main() {
	env := bitwarden.DefaultEnv()
	env.Resolve()

	var initialFilter string
	args := os.Args[1:]

	if len(args) > 0 {
		switch args[0] {
		case "unlock", "lock", "sync", "status", "logout":
			runCommand(env, args)
			return
		default:
			initialFilter = strings.Join(args, " ")
		}
	}

	tui := bitwarden.NewTUI(env, initialFilter)
	p := tea.NewProgram(tui, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runCommand(env *bitwarden.Env, args []string) {
	// Restore session from file if not already in env
	if env.Session == "" {
		if session, err := bitwarden.ReadSessionFromFile(env.SessionFile); err == nil && session != "" {
			env.Session = session
		}
	}
	client := bitwarden.NewClient(env.BwPath, env.Session)

	switch args[0] {
	case "unlock":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Usage: bw unlock <password>")
			fmt.Fprintln(os.Stderr, "       bw unlock          (prompt)")
			os.Exit(1)
		}
		session, err := client.Unlock(args[1])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		if err := bitwarden.WriteSessionFile(env.SessionFile, session); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to write session file: %v\n", err)
		}
		fmt.Println("Vault unlocked.")

	case "lock":
		if err := client.Lock(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Vault locked.")

	case "sync":
		if err := client.Sync(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		// Invalidate cache so next TUI start fetches fresh data
		os.Remove(env.CacheFile)
		fmt.Println("Vault synced.")

	case "status":
		status, err := client.Status()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Println(status)

	case "logout":
		if err := client.Logout(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Logged out.")
	}
}
