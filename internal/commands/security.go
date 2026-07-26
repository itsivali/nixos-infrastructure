package commands

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/security"
	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

func CmdSecurity(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "security",
		Short: "Security audit summary",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println(t.Header("Security Audit"))
			fmt.Println()

			result, err := security.RunFullScan()
			if err != nil {
				fmt.Println(t.CheckList([]terminal.CheckItem{
					{Label: fmt.Sprintf("Scan failed: %s", err), Status: terminal.StatusFail},
				}))
				return nil
			}

			for _, cat := range result.Categories {
				fmt.Println(t.Section(cat.Name))
				for _, check := range cat.Checks {
					status := terminal.StatusPass
					if !check.Pass {
						if check.Severity == "critical" || check.Severity == "high" {
							status = terminal.StatusFail
						} else {
							status = terminal.StatusWarn
						}
					}
					fmt.Println(t.CheckList([]terminal.CheckItem{
						{Label: check.Name, Status: status, Detail: check.Message},
					}))
				}
				fmt.Println()
			}

			fmt.Println(t.Separator())
			fmt.Println(t.Summary("Score", security.ScoreFromResult(result)))
			fmt.Println()

			return nil
		},
	}
}
