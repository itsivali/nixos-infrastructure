package plugin

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

const AIPluginName = "ai"

type AIPlugin struct {
	BasePlugin
}

func NewAIPlugin() *AIPlugin {
	return &AIPlugin{
		BasePlugin: NewBase("AI Systems"),
	}
}

func (p *AIPlugin) Name() string { return AIPluginName }

func (p *AIPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	engine.SetDetail(p.Name(), state.WithVersion("1.0.0"))
	return nil
}

func (p *AIPlugin) Status() *state.ComponentStatus {
	meta := make(map[string]string)

	OpenHandsAvailable := false
	if _, err := exec.LookPath("openhands"); err == nil {
		OpenHandsAvailable = true
	}
	meta["openhands_available"] = fmtBool(OpenHandsAvailable)

	meta["opencode_dir"] = fmtBool(fileExists(".opencode"))
	meta["opencode_knowledge"] = fmtBool(fileExists("opencode/README.md"))

	stateVal := state.StateHealthy
	var messages []string

	if fileExists(".opencode") {
		messages = append(messages, "OpenCode configured")
	} else {
		messages = append(messages, "OpenCode not configured")
		stateVal = state.StateWarning
	}

	if OpenHandsAvailable {
		messages = append(messages, "OpenHands available")
	}

	if fileExists("opencode/README.md") {
		messages = append(messages, "Knowledge base available")
	}

	return &state.ComponentStatus{
		Name:    p.Name(),
		State:   stateVal,
		Message: strings.Join(messages, "; "),
		Metadata: map[string]string{
			"openhands_available": fmtBool(OpenHandsAvailable),
			"opencode_configured": fmtBool(fileExists(".opencode")),
			"knowledge_base":      fmtBool(fileExists("opencode/README.md")),
		},
	}
}

func (p *AIPlugin) Shutdown() error { return nil }

func AISystemStatus() string {
	var parts []string
	if _, err := exec.LookPath("openhands"); err == nil {
		parts = append(parts, "OpenHands: available")
	} else {
		parts = append(parts, "OpenHands: not available")
	}
	if _, err := os.Stat(".opencode"); err == nil {
		parts = append(parts, "OpenCode: configured")
	} else {
		parts = append(parts, "OpenCode: not configured")
	}
	return fmt.Sprintf("AI Systems: %s", strings.Join(parts, ", "))
}
