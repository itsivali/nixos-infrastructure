package main

import (
	"fmt"
	"os"

	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/commands"
)

func main() {
	application, err := app.New(app.InitStandard)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	root := commands.Root(application)

	if err := root.Execute(); err != nil {
		t := application.Term
		fmt.Println()
		fmt.Println("  " + t.Bad(fmt.Sprintf("%v", err)))
		fmt.Println()
		os.Exit(1)
	}
}
