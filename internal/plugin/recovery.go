package plugin

import (
	"os"
	"os/exec"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

const RecoveryPluginName = "recovery"

type RecoveryPlugin struct {
	BasePlugin
}

func NewRecoveryPlugin() *RecoveryPlugin {
	return &RecoveryPlugin{
		BasePlugin: NewBase("Recovery & Backups"),
	}
}

func (p *RecoveryPlugin) Name() string { return RecoveryPluginName }

func (p *RecoveryPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	engine.SetDetail(p.Name(), state.WithVersion("1.0.0"))
	return nil
}

func (p *RecoveryPlugin) Status() *state.ComponentStatus {
	meta := make(map[string]string)

	rollbackAvailable := false
	if _, err := os.Stat("/nix/var/nix/profiles/system"); err == nil {
		rollbackAvailable = true
	}
	meta["rollback_available"] = fmtBool(rollbackAvailable)

	deployHealthActive := false
	if out, err := exec.Command("systemctl", "is-active", "deployment-health.timer").Output(); err == nil {
		deployHealthActive = strings.TrimSpace(string(out)) == "active"
	}
	meta["deployment_health"] = fmtBool(deployHealthActive)

	resticInstalled := false
	if _, err := exec.LookPath("restic"); err == nil {
		resticInstalled = true
	}
	meta["restic_installed"] = fmtBool(resticInstalled)

	backupsConfigured := false
	if _, err := os.Stat("/run/secrets/restic_password"); err == nil {
		backupsConfigured = true
	}
	meta["backups_configured"] = fmtBool(backupsConfigured)

	message := "recovery systems healthy"
	stateVal := state.StateHealthy

	if !deployHealthActive {
		stateVal = state.StateWarning
		message = "deployment health monitoring not active"
	}

	if !resticInstalled {
		stateVal = state.StateWarning
		message = "restic not available"
	}

	return &state.ComponentStatus{
		Name:     p.Name(),
		State:    stateVal,
		Message:  message,
		Metadata: meta,
	}
}

func (p *RecoveryPlugin) Shutdown() error { return nil }
