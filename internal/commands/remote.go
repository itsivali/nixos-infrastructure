package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

// CmdRemote manages the remote-desktop (RDP) backend. It shells out to
// the declaratively installed `ivali-remote-desktop` helper (owned by
// desktop/remote-desktop/grd.nix) so the CLI never drifts from the
// system's actual GRD/grdctl wiring.
func CmdRemote(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "remote",
		Short: "🖥  Remote Desktop (RDP) control",
		Long: `Manage the GNOME Remote Desktop (RDP) backend.

Subcommands:
  status        Show RDP backend + connection status
  enable        Enable the RDP backend for this user
  disable       Disable the RDP backend for this user
  set-port      Override the RDP listen port
  view-only     Toggle remote input control (on/off)
  credentials   Set RDP username/password (GNOME keyring)
  certs         Show TLS certificate status
  daemon        Show GRD systemd user-unit status

Command delegation: every subcommand runs the helper installed by the
NixOS module (ivali-remote-desktop, wrapping grdctl).`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	for _, s := range []struct {
		sub, short, argHelp string
	}{
		{"status", "Show RDP backend + connection status", ""},
		{"enable", "Enable the RDP backend for this user", ""},
		{"disable", "Disable the RDP backend for this user", ""},
		{"set-port", "Override the RDP listen port", "<port>"},
		{"view-only", "Toggle remote input control (on/off)", ""},
		{"credentials", "Set RDP username/password in the keyring", ""},
		{"certs", "Show TLS certificate status", ""},
		{"daemon", "Show GRD systemd user-unit status", ""},
	} {
		sub := s.sub
		short := s.short
		argHelp := s.argHelp

		use := sub
		if argHelp != "" {
			use += " " + argHelp
		}
		cmd.AddCommand(&cobra.Command{
			Use:   use,
			Short: short,
			Args:  cobra.ArbitraryArgs,
			RunE: func(c *cobra.Command, args []string) error {
				argv := append([]string{"ivali-remote-desktop", sub}, args...)
				out, err := exec.Command(argv[0], argv[1:]...).CombinedOutput()
				if err != nil {
					if _, isNotFound := err.(*exec.Error); isNotFound {
						fmt.Println("Remote Desktop is not enabled on this host.")
						fmt.Println("  Enable ivali.desktop.remote-desktop in the host spec.")
						return nil
					}
					fmt.Println(strings.TrimSpace(string(out)))
					return err
				}
				fmt.Print(string(out))
				return nil
			},
		})
	}

	return cmd
}
