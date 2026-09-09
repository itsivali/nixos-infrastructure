package plugin

import (
	"os"
	"strings"

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

	// Detect the installed desktop stack. nixpkgs layers the desktop
	// environment over the generic X server, so any of these session
	// binaries may be present in /run/current-system. Reporting the
	// detection set (rather than a single hard-coded environment) keeps the
	// plugin correct as the host configuration evolves.
	installed := []string{}
	for _, probe := range []struct{ bin, name string }{
		{"gnome-shell", "gnome"},
		{"xfce4-session", "xfce"},
		{"plasmashell", "kde"},
		{"cinnamon-session", "cinnamon"},
	} {
		if fileExists("/run/current-system/sw/bin/" + probe.bin) {
			installed = append(installed, probe.name)
		}
	}
	meta["desktop_stack_installed"] = strings.Join(installed, ",")

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
