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

	julesInstalled := false
	if _, err := exec.LookPath("jules"); err == nil {
		julesInstalled = true
	}
	meta["jules_binary"] = fmtBool(julesInstalled)

	julesAPIKey := false
	if key := os.Getenv("JULES_API_KEY"); key != "" {
		julesAPIKey = true
	} else if _, err := os.ReadFile("/run/secrets/jules-api-key"); err == nil {
		julesAPIKey = true
	}
	meta["jules_api_key"] = fmtBool(julesAPIKey)

	meta["opencode_dir"] = fmtBool(fileExists(".opencode"))
	meta["opencode_knowledge"] = fmtBool(fileExists("opencode/README.md"))

	stateVal := state.StateHealthy
	var messages []string

	if julesInstalled && julesAPIKey {
		messages = append(messages, "Jules ready")
	} else if julesInstalled {
		messages = append(messages, "Jules CLI installed, API key not configured")
		stateVal = state.StateWarning
	} else {
		messages = append(messages, "Jules CLI not installed")
		stateVal = state.StateWarning
	}

	if fileExists(".opencode") {
		messages = append(messages, "OpenCode configured")
	}
	if fileExists("opencode/README.md") {
		messages = append(messages, "Knowledge base available")
	}

	return &state.ComponentStatus{
		Name:    p.Name(),
		State:   stateVal,
		Message: strings.Join(messages, "; "),
		Metadata: map[string]string{
			"jules_binary":        fmtBool(julesInstalled),
			"jules_api_key":       fmtBool(julesAPIKey),
			"jules_ready":         fmtBool(julesInstalled && julesAPIKey),
			"opencode_configured": fmtBool(fileExists(".opencode")),
			"knowledge_base":      fmtBool(fileExists("opencode/README.md")),
		},
	}
}

func (p *AIPlugin) Shutdown() error { return nil }

func (p *AIPlugin) RouteTask(description string) string {
	keywords := []string{"audit", "analyze", "refactor", "modernize", "document", "architecture"}
	for _, kw := range keywords {
		if strings.Contains(strings.ToLower(description), kw) {
			return "jules"
		}
	}
	if len(description) > 200 {
		return "jules"
	}
	return "opencode"
}

func AISystemStatus() string {
	var parts []string
	if _, err := exec.LookPath("jules"); err == nil {
		parts = append(parts, "Jules: installed")
	} else {
		parts = append(parts, "Jules: not installed")
	}
	return fmt.Sprintf("AI Systems: %s", strings.Join(parts, ", "))
}
