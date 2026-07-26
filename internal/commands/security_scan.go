package commands

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/security"
)

func CmdSecurityScan(a *app.App) *cobra.Command {
	var jsonOutput bool

	cmd := &cobra.Command{
		Use:   "security-scan",
		Short: "Run comprehensive security scan",
		Long: `Run a comprehensive security scan checking:
  - Firewall (nftables policy, SSH restrictions)
  - Kernel hardening (slab_nomerge, init_on_alloc, kptr_restrict, etc.)
  - SSH configuration (password auth, root login)
  - Service status (sshd, tailscale, fail2ban, NetworkManager)
  - Secret management (SOPS key, runtime secrets)
  - Filesystem protections (hardlinks, symlinks)

Use --json for machine-readable output.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println()
			fmt.Println(t.Section("Security Scan"))
			fmt.Println(t.Dim("  Running comprehensive security checks..."))
			fmt.Println()

			result, err := security.RunFullScan()
			if err != nil {
				return fmt.Errorf("running security scan: %w", err)
			}

			if jsonOutput {
				fmt.Println(security.FormatJSON(result))
				return nil
			}

			fmt.Println(security.FormatResult(result))
			fmt.Println(t.Separator())
			fmt.Println(t.KeyValue("Score", security.ScoreFromResult(result)))
			fmt.Println()

			return nil
		},
	}

	cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output as JSON")
	return cmd
}
