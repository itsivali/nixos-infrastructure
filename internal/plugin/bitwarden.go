package plugin

import (
	"os/exec"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

const BitwardenPluginName = "bitwarden"

type BitwardenPlugin struct {
	BasePlugin
}

func NewBitwardenPlugin() *BitwardenPlugin {
	return &BitwardenPlugin{
		BasePlugin: NewBase("Bitwarden Vault"),
	}
}

func (p *BitwardenPlugin) Name() string { return BitwardenPluginName }

func (p *BitwardenPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	engine.SetDetail(p.Name(),
		state.WithVersion("1.0.0"),
	)
	return nil
}

func (p *BitwardenPlugin) Status() *state.ComponentStatus {
	bwStatus := "not installed"
	if _, err := exec.LookPath("bw"); err == nil {
		bwStatus = "installed"
	}

	sessionExists := false
	if out, err := exec.Command("sh", "-c", "ls /run/user/$(id -u)/bitwarden/session 2>/dev/null").Output(); err == nil && len(out) > 0 {
		sessionExists = true
	}

	stateVal := state.StateHealthy
	message := "bitwarden-cli available"
	if !sessionExists {
		message = "bitwarden-cli installed, no active session"
		stateVal = state.StateWarning
	}

	return &state.ComponentStatus{
		Name:    p.Name(),
		State:   stateVal,
		Message: message,
		Metadata: map[string]string{
			"binary":  bwStatus,
			"session": fmtBool(sessionExists),
		},
	}
}

func (p *BitwardenPlugin) Shutdown() error { return nil }

func fmtBool(b bool) string {
	if b {
		return "active"
	}
	return "inactive"
}
