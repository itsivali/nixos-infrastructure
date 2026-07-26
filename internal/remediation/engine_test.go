package remediation

import (
	"sync/atomic"
	"testing"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

type mockAction struct {
	name    string
	canFix  bool
	fixFunc func(comp *state.ComponentStatus) (*Result, error)
}

func (m *mockAction) Name() string { return m.name }

func (m *mockAction) CanFix(comp *state.ComponentStatus) bool {
	return m.canFix
}

func (m *mockAction) Fix(comp *state.ComponentStatus) (*Result, error) {
	if m.fixFunc != nil {
		return m.fixFunc(comp)
	}
	return &Result{
		Success:   true,
		Message:   "mock fix applied",
		Duration:  time.Millisecond,
		Timestamp: time.Now(),
	}, nil
}

func TestEngineRegisterAction(t *testing.T) {
	st := state.New()
	bus := events.New()
	engine := NewEngine(st, bus)

	action := &mockAction{name: "test-action", canFix: true}
	engine.RegisterAction(action)

	if engine.ActionCount() != 1 {
		t.Errorf("expected 1 action, got %d", engine.ActionCount())
	}
}

func TestEngineAttemptRemediation(t *testing.T) {
	st := state.New()
	bus := events.New()
	engine := NewEngine(st, bus)
	engine.Start()

	var fixed atomic.Bool
	action := &mockAction{
		name:   "test-fix",
		canFix: true,
		fixFunc: func(comp *state.ComponentStatus) (*Result, error) {
			fixed.Store(true)
			return &Result{
				Success:   true,
				Message:   "fixed",
				Duration:  time.Millisecond,
				Timestamp: time.Now(),
			}, nil
		},
	}
	engine.RegisterAction(action)

	st.Register("test-component", "Test", "service")
	st.Set("test-component", state.StateDegraded, "test failure")

	time.Sleep(100 * time.Millisecond)

	if !fixed.Load() {
		t.Error("expected fix to be applied")
	}

	comp, ok := st.Get("test-component")
	if !ok {
		t.Fatal("expected component to exist")
	}
	if comp.State != state.StateHealthy {
		t.Errorf("expected healthy state, got %v", comp.State)
	}

	engine.Stop()
}

func TestEngineHistory(t *testing.T) {
	st := state.New()
	bus := events.New()
	engine := NewEngine(st, bus)
	engine.Start()

	action := &mockAction{name: "test-action", canFix: true}
	engine.RegisterAction(action)

	st.Register("test-component", "Test", "service")
	st.Set("test-component", state.StateDegraded, "test failure")

	time.Sleep(100 * time.Millisecond)

	history := engine.History()
	if len(history) == 0 {
		t.Error("expected history to have entries")
	}

	engine.Stop()
}

func TestEngineStartStop(t *testing.T) {
	st := state.New()
	bus := events.New()
	engine := NewEngine(st, bus)

	engine.Start()
	if !engine.running {
		t.Error("expected engine to be running")
	}

	engine.Stop()
	if engine.running {
		t.Error("expected engine to be stopped")
	}
}

func TestServiceRestartAction(t *testing.T) {
	action := NewServiceRestartAction()
	if action.Name() != "service-restart" {
		t.Errorf("expected service-restart, got %s", action.Name())
	}

	comp := &state.ComponentStatus{
		Name: "test-service",
		Kind: "service",
	}
	if !action.CanFix(comp) {
		t.Error("expected CanFix to return true for service")
	}

	comp2 := &state.ComponentStatus{
		Name: "test-nixos",
		Kind: "nixos",
	}
	if action.CanFix(comp2) {
		t.Error("expected CanFix to return false for nixos")
	}
}

func TestDiskCleanupAction(t *testing.T) {
	action := NewDiskCleanupAction()
	if action.Name() != "disk-cleanup" {
		t.Errorf("expected disk-cleanup, got %s", action.Name())
	}

	comp := &state.ComponentStatus{
		Name: "disk",
	}
	if !action.CanFix(comp) {
		t.Error("expected CanFix to return true for disk")
	}

	comp2 := &state.ComponentStatus{
		Name: "other",
	}
	if action.CanFix(comp2) {
		t.Error("expected CanFix to return false for other")
	}
}

func TestNetworkResetAction(t *testing.T) {
	action := NewNetworkResetAction()
	if action.Name() != "network-reset" {
		t.Errorf("expected network-reset, got %s", action.Name())
	}

	comp := &state.ComponentStatus{
		Name: "tailscale",
	}
	if !action.CanFix(comp) {
		t.Error("expected CanFix to return true for tailscale")
	}
}
