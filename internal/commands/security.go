package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdSecurity(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "security",
		Short: "🔒  Security audit summary",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println(t.Header("🔒 Security Audit"))
			fmt.Println()

			type check struct {
				name string
				cmd  string
				pass string
			}

			checks := []check{
				{"AppArmor", "aa-status --enabled 2>/dev/null", "enabled"},
				{"Fail2ban", "systemctl is-active fail2ban 2>/dev/null", "active"},
				{"SSH daemon", "systemctl is-active sshd 2>/dev/null", "active"},
				{"Tailscale", "systemctl is-active tailscaled 2>/dev/null", "active"},
				{"Auditd", "systemctl is-active auditd 2>/dev/null", "active"},
			}

			fmt.Println(t.Section("Service Status"))
			for _, c := range checks {
				out, _ := exec.Command("sh", "-c", c.cmd).CombinedOutput()
				state := strings.TrimSpace(string(out))
				icon := t.Bad("✗")
				if state == c.pass {
					icon = t.Good("✓")
				}
				fmt.Println(fmt.Sprintf("  %s %-20s %s", icon, c.name, state))
			}

			fmt.Println()
			fmt.Println(t.Section("SSH Configuration"))
			sshSettings := []string{
				"grep -E '^PasswordAuthentication|^PermitRootLogin|^AllowUsers' /etc/ssh/sshd_config 2>/dev/null",
			}
			for _, cmd := range sshSettings {
				out, err := exec.Command("sh", "-c", cmd).CombinedOutput()
				if err == nil {
					for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
						if line != "" {
							fmt.Println(t.Dim(fmt.Sprintf("  %s", line)))
						}
					}
				}
			}

			fmt.Println()
			fmt.Println(t.Section("Kernel Hardening"))
			hardening := []string{"slab_nomerge", "init_on_alloc=1", "init_on_free=1", "pti=on", "randomize_kstack_offset=on"}
			for _, flag := range hardening {
				out, _ := exec.Command("sh", "-c",
					fmt.Sprintf("grep -qw '\\(%s\\|%s=1\\)' /proc/cmdline 2>/dev/null && echo yes || echo no", flag, flag)).CombinedOutput()
				state := strings.TrimSpace(string(out))
				icon := t.Bad("✗")
				if state == "yes" {
					icon = t.Good("✓")
				}
				fmt.Println(fmt.Sprintf("  %s %s", icon, flag))
			}

			fmt.Println()
			fmt.Println(t.Section("Firewall"))
			nftOut, err := exec.Command("nft", "list", "ruleset").CombinedOutput()
			if err != nil {
				fmt.Println(t.Bad("  nftables not available"))
			} else {
				rules := strings.Split(string(nftOut), "\n")
				rulesCount := 0
				for _, r := range rules {
					if strings.Contains(r, "rule") {
						rulesCount++
					}
				}
				fmt.Println(fmt.Sprintf("  %s nftables active  •  %d rules", t.Good("✓"), rulesCount))
			}

			return nil
		},
	}
}
