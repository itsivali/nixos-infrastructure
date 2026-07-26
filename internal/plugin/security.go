package plugin

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

const SecurityPluginName = "security"

type SecurityPlugin struct {
	BasePlugin
}

func NewSecurityPlugin() *SecurityPlugin {
	return &SecurityPlugin{
		BasePlugin: NewBase("Security Audit", "gitops"),
	}
}

func (p *SecurityPlugin) Name() string { return SecurityPluginName }

func (p *SecurityPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	engine.SetDetail(p.Name(),
		state.WithVersion("1.0.0"),
		state.WithMeta("checks", "apparmor,firewall,fail2ban,kernel,tailscale"),
	)
	return nil
}

func (p *SecurityPlugin) Status() *state.ComponentStatus {
	type check struct {
		name string
		cmd  string
		pass string
	}

	checks := []check{
		{"apparmor", "aa-status --enabled 2>/dev/null", "enabled"},
		{"firewall", "nft list ruleset 2>/dev/null | grep -q 'policy drop'", ""},
		{"fail2ban", "systemctl is-active fail2ban 2>/dev/null", "active"},
		{"ssh", "sshd -T 2>/dev/null | grep -q '^passwordauthentication no'", ""},
		{"kernel", "grep -qw 'slab_nomerge' /proc/cmdline 2>/dev/null", ""},
		{"kptr_restrict", "cat /proc/sys/kernel/kptr_restrict 2>/dev/null | grep -q '^2$'", ""},
		{"dmesg_restrict", "cat /proc/sys/kernel/dmesg_restrict 2>/dev/null | grep -q '^1$'", ""},
		{"ptrace", "cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null | grep -q '^[12]$'", ""},
		{"coredump", "cat /proc/sys/fs/suid_dumpable 2>/dev/null | grep -q '^0$'", ""},
		{"tailscale", "systemctl is-active tailscaled 2>/dev/null", "active"},
	}

	healthy := true
	var details []string
	for _, c := range checks {
		err := exec.Command("sh", "-c", c.cmd).Run()
		if err != nil {
			healthy = false
			details = append(details, fmt.Sprintf("%s: fail", c.name))
		} else {
			details = append(details, fmt.Sprintf("%s: pass", c.name))
		}
	}

	stateVal := state.StateHealthy
	message := "all security checks passed"
	if !healthy {
		stateVal = state.StateWarning
		message = strings.Join(details, "; ")
	}

	return &state.ComponentStatus{
		Name:    p.Name(),
		State:   stateVal,
		Message: message,
		Metadata: map[string]string{
			"checks": strings.Join([]string{"apparmor", "firewall", "fail2ban", "ssh", "kernel", "kptr_restrict", "dmesg_restrict", "ptrace", "coredump", "tailscale"}, ","),
		},
	}
}

func (p *SecurityPlugin) Shutdown() error { return nil }
