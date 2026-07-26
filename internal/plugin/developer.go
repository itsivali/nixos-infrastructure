package plugin

import (
	"os/exec"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

const DeveloperPluginName = "developer"

type DeveloperPlugin struct {
	BasePlugin
}

func NewDeveloperPlugin() *DeveloperPlugin {
	return &DeveloperPlugin{
		BasePlugin: NewBase("Developer Toolchain"),
	}
}

func (p *DeveloperPlugin) Name() string { return DeveloperPluginName }

func (p *DeveloperPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	engine.SetDetail(p.Name(), state.WithVersion("1.0.0"))
	return nil
}

func (p *DeveloperPlugin) Status() *state.ComponentStatus {
	tools := []struct {
		name    string
		binary  string
		version string
	}{
		{"go", "go", "go version"},
		{"nix", "nix", "nix --version"},
		{"git", "git", "git --version"},
		{"node", "node", "node --version"},
		{"python", "python3", "python3 --version"},
		{"just", "just", "just --version 2>/dev/null || true"},
	}

	meta := make(map[string]string)
	var missing []string

	for _, tool := range tools {
		if _, err := exec.LookPath(tool.binary); err == nil {
			if out, err := exec.Command("sh", "-c", tool.version).Output(); err == nil {
				meta[tool.name] = strings.TrimSpace(string(out))
			} else {
				meta[tool.name] = "installed"
			}
		} else {
			missing = append(missing, tool.name)
		}
	}

	stateVal := state.StateHealthy
	message := "all developer tools available"

	if len(missing) > 0 {
		if len(missing) <= 2 {
			stateVal = state.StateWarning
		} else {
			stateVal = state.StateDegraded
		}
		message = "missing: " + strings.Join(missing, ", ")
	}

	return &state.ComponentStatus{
		Name:     p.Name(),
		State:    stateVal,
		Message:  message,
		Metadata: meta,
	}
}

func (p *DeveloperPlugin) Shutdown() error { return nil }
