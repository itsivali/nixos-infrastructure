package commands

import (
	"encoding/json"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

func CmdGenerations(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "generations",
		Short: "List NixOS system generations",
		Long: `Display all available NixOS system generations with their status
(active/current) and creation timestamps.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			svc := operations.NewGenerationService()
			generations, err := svc.List(cmd.Context())
			if err != nil {
				return fmt.Errorf("list generations: %w", err)
			}

			if a.JSONOutput {
				data, _ := json.MarshalIndent(generations, "", "  ")
				fmt.Println(string(data))
				return nil
			}

			fmt.Println()
			fmt.Println(t.Section("NixOS Generations"))
			fmt.Println()

			if len(generations) == 0 {
				fmt.Println(t.Dim("  No generations found"))
				fmt.Println()
				return nil
			}

			for _, gen := range generations {
				status := t.Dim("  ")
				if gen.Active {
					status = t.Good("★ ")
				}
				dateStr := gen.Date.Format("2006-01-02 15:04:05")
				if dateStr == "0001-01-01 00:00:00" {
					dateStr = "unknown"
				}
				fmt.Printf("  %s%s %s\n", status, fmt.Sprintf("Gen %d", gen.Number), t.Dim(dateStr))
			}
			fmt.Println()

			return nil
		},
	}
}
