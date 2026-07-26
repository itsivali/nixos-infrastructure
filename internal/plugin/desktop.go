package plugin

import (
	"os"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

const DesktopPluginName = "desktop"

type DesktopPlugin struct {
	BasePlugin
}

func NewDesktopPlugin() *DesktopPlugin {
	return &DesktopPlugin{
		BasePlugin: NewBase("Desktop Environment"),
	}
}

func (p *DesktopPlugin) Name() string { return DesktopPluginName }

func (p *DesktopPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	engine.SetDetail(p.Name(), state.WithVersion("1.0.0"))
	return nil
}

func (p *DesktopPlugin) Status() *state.ComponentStatus {
	meta := make(map[string]string)

	sessionType := "unknown"
	if v := os.Getenv("WAYLAND_DISPLAY"); v != "" {
		sessionType = "wayland"
	} else if v := os.Getenv("DISPLAY"); v != "" {
		sessionType = "x11"
	}
	meta["session_type"] = sessionType

	desktopEnv := "unknown"
	if v := os.Getenv("XDG_CURRENT_DESKTOP"); v != "" {
		desktopEnv = v
	}
	meta["desktop"] = desktopEnv

	gnomePresent := false
	if _, err := os.Stat("/run/current-system/sw/bin/gnome-shell"); err == nil {
		gnomePresent = true
	}
	meta["gnome_installed"] = fmtBool(gnomePresent)

	stateVal := state.StateHealthy
	message := "desktop session active"

	if desktopEnv == "unknown" {
		stateVal = state.StateWarning
		message = "no desktop session detected"
	}
	if sessionType == "unknown" {
		stateVal = state.StateDegraded
		message = "no display server detected"
	}

	return &state.ComponentStatus{
		Name:     p.Name(),
		State:    stateVal,
		Message:  message,
		Metadata: meta,
	}
}

func (p *DesktopPlugin) Shutdown() error { return nil }

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
