package plugin

import (
	"fmt"
	"net/http"
	"os/exec"
	"strings"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

const ObservabilityPluginName = "observability"

type ObservabilityPlugin struct {
	BasePlugin
}

func NewObservabilityPlugin() *ObservabilityPlugin {
	return &ObservabilityPlugin{
		BasePlugin: NewBase("Observability Stack"),
	}
}

func (p *ObservabilityPlugin) Name() string { return ObservabilityPluginName }

func (p *ObservabilityPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	engine.SetDetail(p.Name(), state.WithVersion("1.0.0"))
	return nil
}

func (p *ObservabilityPlugin) Status() *state.ComponentStatus {
	services := []struct {
		name string
		url  string
	}{
		{"prometheus", "http://127.0.0.1:9090/-/healthy"},
		{"grafana", "http://127.0.0.1:3000/grafana/api/health"},
		{"loki", "http://127.0.0.1:3100/ready"},
	}

	meta := make(map[string]string)
	healthy := true
	var details []string
	client := &http.Client{Timeout: 3 * time.Second}

	for _, svc := range services {
		resp, err := client.Get(svc.url)
		if err == nil {
			resp.Body.Close()
			meta[svc.name] = "up"
			details = append(details, fmt.Sprintf("%s: up", svc.name))
		} else {
			healthy = false
			meta[svc.name] = "down"
			details = append(details, fmt.Sprintf("%s: down", svc.name))
		}
	}

	nixosExporter := false
	if out, err := exec.Command("ss", "-tlnp").Output(); err == nil {
		nixosExporter = strings.Contains(string(out), "9101")
	}
	meta["nixos_exporter"] = fmtBool(nixosExporter)

	stateVal := state.StateHealthy
	message := "all observability services healthy"
	if !healthy {
		stateVal = state.StateWarning
		message = strings.Join(details, "; ")
	}

	return &state.ComponentStatus{
		Name:     p.Name(),
		State:    stateVal,
		Message:  message,
		Metadata: meta,
	}
}

func (p *ObservabilityPlugin) Shutdown() error { return nil }
