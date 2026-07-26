package plugin

import (
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

type testPlugin struct {
	BasePlugin
	engine         *state.Engine
	initCalled     bool
	shutdownCalled bool
}

func (p *testPlugin) Name() string { return "test-plugin" }
func (p *testPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	p.engine = engine
	p.initCalled = true
	engine.Set(p.Name(), state.StateHealthy, "initialized")
	return nil
}
func (p *testPlugin) Status() *state.ComponentStatus {
	if p.engine == nil {
		return &state.ComponentStatus{Name: p.Name(), State: state.StateUnknown}
	}
	comp, ok := p.engine.Get(p.Name())
	if !ok {
		return &state.ComponentStatus{Name: p.Name(), State: state.StateUnknown}
	}
	return &comp
}
func (p *testPlugin) Shutdown() error {
	p.shutdownCalled = true
	return nil
}

type failingPlugin struct {
	BasePlugin
}

func (p *failingPlugin) Name() string { return "failing-plugin" }
func (p *failingPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	return nil
}
func (p *failingPlugin) Status() *state.ComponentStatus { return nil }
func (p *failingPlugin) Shutdown() error                { return nil }

func TestRegistryRegister(t *testing.T) {
	eng := state.New()
	bus := events.New()
	r := NewRegistry(eng, bus)

	p := &testPlugin{BasePlugin: NewBase("Test Plugin")}
	err := r.Register(p)
	if err != nil {
		t.Fatalf("Register() error = %v", err)
	}

	if r.PluginCount() != 1 {
		t.Errorf("PluginCount = %d, want 1", r.PluginCount())
	}

	got, ok := r.Get("test-plugin")
	if !ok {
		t.Fatal("expected plugin to be found")
	}
	if got.Name() != "test-plugin" {
		t.Errorf("Name = %q, want %q", got.Name(), "test-plugin")
	}

	comp, ok := eng.Get("test-plugin")
	if !ok {
		t.Fatal("expected component in state engine")
	}
	if comp.State != state.StateUnknown {
		t.Errorf("State = %v, want %v", comp.State, state.StateUnknown)
	}
}

func TestRegistryRegisterDuplicate(t *testing.T) {
	eng := state.New()
	bus := events.New()
	r := NewRegistry(eng, bus)

	p1 := &testPlugin{BasePlugin: NewBase("Test Plugin")}
	p2 := &testPlugin{BasePlugin: NewBase("Test Plugin")}

	if err := r.Register(p1); err != nil {
		t.Fatalf("first Register() error = %v", err)
	}
	if err := r.Register(p2); err == nil {
		t.Error("expected error for duplicate registration")
	}
}

func TestRegistryRegisterMissingDependency(t *testing.T) {
	eng := state.New()
	bus := events.New()
	r := NewRegistry(eng, bus)

	p := &testPlugin{BasePlugin: NewBase("Test Plugin", "missing-dep")}
	err := r.Register(p)
	if err == nil {
		t.Error("expected error for missing dependency")
	}
}

func TestRegistryInitAll(t *testing.T) {
	eng := state.New()
	bus := events.New()
	r := NewRegistry(eng, bus)

	p := &testPlugin{BasePlugin: NewBase("Test Plugin")}
	if err := r.Register(p); err != nil {
		t.Fatalf("Register() error = %v", err)
	}

	errs := r.InitAll()
	if len(errs) != 0 {
		t.Fatalf("InitAll() errors = %v", errs)
	}

	if !p.initCalled {
		t.Error("expected plugin.Init to be called")
	}

	comp, _ := eng.Get("test-plugin")
	if comp.State != state.StateHealthy {
		t.Errorf("State = %v, want %v", comp.State, state.StateHealthy)
	}
}

func TestRegistryAll(t *testing.T) {
	eng := state.New()
	bus := events.New()
	r := NewRegistry(eng, bus)

	_ = r.Register(&testPlugin{BasePlugin: NewBase("Test")})
	_ = r.Register(&failingPlugin{BasePlugin: NewBase("Failing")})

	plugins := r.All()
	if len(plugins) != 2 {
		t.Errorf("got %d plugins, want 2", len(plugins))
	}
}

func TestRegistryList(t *testing.T) {
	eng := state.New()
	bus := events.New()
	r := NewRegistry(eng, bus)

	_ = r.Register(&testPlugin{BasePlugin: NewBase("Test Plugin")})
	list := r.List()
	if list == "" {
		t.Error("expected non-empty list")
	}
}

func TestRegistryShutdownAll(t *testing.T) {
	eng := state.New()
	bus := events.New()
	r := NewRegistry(eng, bus)

	p := &testPlugin{BasePlugin: NewBase("Test Plugin")}
	if err := r.Register(p); err != nil {
		t.Fatalf("Register() error = %v", err)
	}

	r.InitAll()
	errs := r.ShutdownAll()
	if len(errs) != 0 {
		t.Fatalf("ShutdownAll() errors = %v", errs)
	}
	if !p.shutdownCalled {
		t.Error("expected plugin.Shutdown to be called")
	}
}

func TestRegistryStatusAll(t *testing.T) {
	eng := state.New()
	bus := events.New()
	r := NewRegistry(eng, bus)

	_ = r.Register(&testPlugin{BasePlugin: NewBase("Test")})
	r.InitAll()

	statuses := r.StatusAll()
	if len(statuses) != 1 {
		t.Errorf("got %d statuses, want 1", len(statuses))
	}
}
