package commands

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

// CmdSecrets audits the encrypted SOPS secret files: it lists each file,
// shows its SOPS recipients via `sops filestatus`, and reports which
// secrets have been decrypted into /run/secrets at runtime.
func CmdSecrets(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "secrets",
		Short: "Audit SOPS secrets (recipients and presence)",
		Long: `List the encrypted secret files in secrets/, show their SOPS
recipients (via sops filestatus), and report which are currently
decrypted into /run/secrets.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			t := a.Term
			r := a.Repo
			secretDir := filepath.Join(r.Root, "secrets")

			fmt.Println()
			fmt.Println(t.Section("SOPS Secrets Audit"))
			fmt.Println()

			entries, err := os.ReadDir(secretDir)
			if err != nil {
				fmt.Println(t.Bad(fmt.Sprintf("cannot read %s", secretDir)))
				return nil
			}
			for _, e := range entries {
				if e.IsDir() || !strings.HasSuffix(e.Name(), ".yaml") {
					continue
				}
				path := filepath.Join(secretDir, e.Name())
				fmt.Println(t.KeyValue("File", e.Name()))
				if out, err := exec.Command("sops", "filestatus", path).CombinedOutput(); err == nil {
					fmt.Println(strings.TrimRight(string(out), "\n"))
				} else {
					fmt.Println(t.Dim("  (sops filestatus unavailable)"))
				}
			}

			fmt.Println()
			fmt.Println(t.Section("Decrypted (/run/secrets)"))
			if de, err := os.ReadDir("/run/secrets"); err == nil {
				if len(de) == 0 {
					fmt.Println(t.Dim("  none decrypted"))
				}
				for _, e := range de {
					fmt.Println(t.Dim("  - " + e.Name()))
				}
			} else {
				fmt.Println(t.Dim("  /run/secrets not present"))
			}
			fmt.Println()
			return nil
		},
	}
}
