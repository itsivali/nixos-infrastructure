package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdFirewall(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "firewall",
		Short: "🛡️  Show nftables firewall rules",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println(t.Header("🛡️  Firewall Status"))
			fmt.Println()

			out, err := exec.Command("nft", "list", "ruleset").CombinedOutput()
			if err != nil {
				fmt.Println(t.Bad("nftables not available"))
				fmt.Println(t.Dim(string(out)))
				return nil
			}

			ruleset := string(out)
			lines := strings.Split(ruleset, "\n")

			rulesCount := 0
			for _, line := range lines {
				if strings.Contains(line, "rule") || strings.HasPrefix(strings.TrimSpace(line), "handle") {
					rulesCount++
				}
			}

			fmt.Println(t.Section("Summary"))
			fmt.Println(t.KeyValue("Rules", fmt.Sprintf("%d", rulesCount)))
			fmt.Println(t.KeyValue("Lines", fmt.Sprintf("%d", len(lines))))

			hooks := []string{}
			for _, line := range lines {
				line = strings.TrimSpace(line)
				if strings.HasPrefix(line, "hook ") {
					hooks = append(hooks, line)
				}
			}
			if len(hooks) > 0 {
				fmt.Println(t.KeyValue("Hooks", strings.Join(hooks, ", ")))
			}
			fmt.Println()

			fmt.Println(t.Section("Ruleset Preview (first 40 lines)"))
			preview := strings.Join(lines[:min(40, len(lines))], "\n")
			fmt.Println(t.Dim(preview))
			if len(lines) > 40 {
				fmt.Println(t.Dim(fmt.Sprintf("... (%d more lines)", len(lines)-40)))
			}

			return nil
		},
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
