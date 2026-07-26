package state

import (
	"testing"
	"time"
)

func TestStateString(t *testing.T) {
	tests := []struct {
		s    State
		want string
	}{
		{StateHealthy, "healthy"},
		{StateWarning, "warning"},
		{StateDegraded, "degraded"},
		{StateOffline, "offline"},
		{StateUnknown, "unknown"},
		{State(99), "unknown"},
	}
	for _, tt := range tests {
		if got := tt.s.String(); got != tt.want {
			t.Errorf("State(%d).String() = %q, want %q", tt.s, got, tt.want)
		}
	}
}

func TestParseState(t *testing.T) {
	tests := []struct {
		s    string
		want State
	}{
		{"healthy", StateHealthy},
		{"warning", StateWarning},
		{"degraded", StateDegraded},
		{"offline", StateOffline},
		{"unknown", StateUnknown},
		{"invalid", StateUnknown},
	}
	for _, tt := range tests {
		if got := ParseState(tt.s); got != tt.want {
			t.Errorf("ParseState(%q) = %v, want %v", tt.s, got, tt.want)
		}
	}
}

func TestEngineRegister(t *testing.T) {
	e := New()
	e.Register("test", "Test Component", "test")

	comp, ok := e.Get("test")
	if !ok {
		t.Fatal("expected component to be registered")
	}
	if comp.Name != "test" {
		t.Errorf("Name = %q, want %q", comp.Name, "test")
	}
	if comp.State != StateUnknown {
		t.Errorf("State = %v, want %v", comp.State, StateUnknown)
	}
}

func TestEngineSetState(t *testing.T) {
	e := New()
	e.Register("svc", "Service", "service")

	e.Set("svc", StateHealthy, "all good")
	comp, _ := e.Get("svc")
	if comp.State != StateHealthy {
		t.Errorf("State = %v, want %v", comp.State, StateHealthy)
	}
	if comp.Message != "all good" {
		t.Errorf("Message = %q, want %q", comp.Message, "all good")
	}
	if comp.LastSuccess.IsZero() {
		t.Error("expected LastSuccess to be set")
	}
	if comp.ErrorCount != 0 {
		t.Errorf("ErrorCount = %d, want 0", comp.ErrorCount)
	}
}

func TestEngineSetDegradedIncrementsErrors(t *testing.T) {
	e := New()
	e.Register("svc", "Service", "service")

	e.Set("svc", StateDegraded, "something wrong")
	comp, _ := e.Get("svc")
	if comp.State != StateDegraded {
		t.Errorf("State = %v, want %v", comp.State, StateDegraded)
	}
	if comp.ErrorCount != 1 {
		t.Errorf("ErrorCount = %d, want 1", comp.ErrorCount)
	}
	if comp.LastFailure.IsZero() {
		t.Error("expected LastFailure to be set")
	}

	e.Set("svc", StateDegraded, "still wrong")
	comp, _ = e.Get("svc")
	if comp.ErrorCount != 2 {
		t.Errorf("ErrorCount = %d, want 2", comp.ErrorCount)
	}
}

func TestEngineDynamicRegistration(t *testing.T) {
	e := New()
	e.Set("dynamic-component", StateHealthy, "auto-registered")

	comp, ok := e.Get("dynamic-component")
	if !ok {
		t.Fatal("expected dynamic component to exist")
	}
	if comp.State != StateHealthy {
		t.Errorf("State = %v, want %v", comp.State, StateHealthy)
	}
}

func TestEngineSubscribe(t *testing.T) {
	e := New()
	e.Register("test", "Test", "test")

	notified := make(chan struct {
		name string
		old  State
		new  State
	}, 1)

	e.Subscribe(func(name string, old, new State) {
		notified <- struct {
			name string
			old  State
			new  State
		}{name, old, new}
	})

	e.Set("test", StateHealthy, "ok")

	select {
	case n := <-notified:
		if n.name != "test" {
			t.Errorf("name = %q, want %q", n.name, "test")
		}
		if n.old != StateUnknown {
			t.Errorf("old = %v, want %v", n.old, StateUnknown)
		}
		if n.new != StateHealthy {
			t.Errorf("new = %v, want %v", n.new, StateHealthy)
		}
	case <-time.After(time.Second):
		t.Fatal("listener was not called")
	}
}

func TestEngineAll(t *testing.T) {
	e := New()
	e.Register("a", "A", "type")
	e.Register("b", "B", "type")
	e.Set("a", StateHealthy, "")
	e.Set("b", StateWarning, "")

	all := e.All()
	if len(all) != 2 {
		t.Errorf("got %d components, want 2", len(all))
	}
}

func TestEngineByState(t *testing.T) {
	e := New()
	e.Register("a", "A", "type")
	e.Register("b", "B", "type")
	e.Register("c", "C", "type")
	e.Set("a", StateHealthy, "")
	e.Set("b", StateWarning, "")
	e.Set("c", StateDegraded, "")

	healthy := e.ByState(StateHealthy)
	if len(healthy) != 1 || healthy[0].Name != "a" {
		t.Errorf("expected 1 healthy component, got %v", healthy)
	}

	degraded := e.ByState(StateDegraded)
	if len(degraded) != 1 || degraded[0].Name != "c" {
		t.Errorf("expected 1 degraded component, got %v", degraded)
	}
}

func TestEngineNonHealthy(t *testing.T) {
	e := New()
	e.Register("a", "A", "type")
	e.Register("b", "B", "type")
	e.Register("c", "C", "type")
	e.Set("a", StateHealthy, "")
	e.Set("b", StateWarning, "")
	e.Set("c", StateDegraded, "")

	nonHealthy := e.NonHealthy()
	if len(nonHealthy) != 2 {
		t.Errorf("expected 2 non-healthy components, got %d", len(nonHealthy))
	}
}

func TestEngineGlobalState(t *testing.T) {
	t.Run("all healthy", func(t *testing.T) {
		e := New()
		e.Register("a", "A", "type")
		e.Register("b", "B", "type")
		e.Set("a", StateHealthy, "")
		e.Set("b", StateHealthy, "")
		if gs := e.GlobalState(); gs != StateHealthy {
			t.Errorf("GlobalState = %v, want %v", gs, StateHealthy)
		}
	})

	t.Run("with warning", func(t *testing.T) {
		e := New()
		e.Register("a", "A", "type")
		e.Register("b", "B", "type")
		e.Set("a", StateHealthy, "")
		e.Set("b", StateWarning, "")
		if gs := e.GlobalState(); gs != StateWarning {
			t.Errorf("GlobalState = %v, want %v", gs, StateWarning)
		}
	})

	t.Run("degraded overrides warning", func(t *testing.T) {
		e := New()
		e.Register("a", "A", "type")
		e.Register("b", "B", "type")
		e.Set("a", StateDegraded, "")
		e.Set("b", StateWarning, "")
		if gs := e.GlobalState(); gs != StateDegraded {
			t.Errorf("GlobalState = %v, want %v", gs, StateDegraded)
		}
	})

	t.Run("offline is worst", func(t *testing.T) {
		e := New()
		e.Register("a", "A", "type")
		e.Register("b", "B", "type")
		e.Set("a", StateOffline, "")
		e.Set("b", StateHealthy, "")
		if gs := e.GlobalState(); gs != StateOffline {
			t.Errorf("GlobalState = %v, want %v", gs, StateOffline)
		}
	})

	t.Run("empty engine returns unknown", func(t *testing.T) {
		e := New()
		if gs := e.GlobalState(); gs != StateUnknown {
			t.Errorf("GlobalState = %v, want %v", gs, StateUnknown)
		}
	})
}

func TestEngineSummary(t *testing.T) {
	e := New()
	e.Register("a", "A", "type")
	e.Register("b", "B", "type")
	e.Register("c", "C", "type")
	e.Set("a", StateHealthy, "")
	e.Set("b", StateWarning, "")
	e.Set("c", StateDegraded, "")

	summary := e.Summary()
	if summary == "" {
		t.Error("expected non-empty summary")
	}
}

func TestEngineSetDetail(t *testing.T) {
	e := New()
	e.Register("test", "Test", "test")

	e.SetDetail("test",
		WithVersion("1.0.0"),
		WithDisplayName("Test Component"),
		WithDependencies([]string{"dep-a", "dep-b", "dep-c"}),
		WithMeta("key1", "val1"),
		WithMetaMap(map[string]string{"key2": "val2"}),
	)

	comp, _ := e.Get("test")
	if comp.Version != "1.0.0" {
		t.Errorf("Version = %q, want %q", comp.Version, "1.0.0")
	}
	if comp.DisplayName != "Test Component" {
		t.Errorf("DisplayName = %q, want %q", comp.DisplayName, "Test Component")
	}
	if len(comp.Dependencies) != 3 {
		t.Errorf("expected 3 dependencies, got %d", len(comp.Dependencies))
	}
	if comp.Metadata["key1"] != "val1" {
		t.Errorf("Metadata[key1] = %q, want %q", comp.Metadata["key1"], "val1")
	}
	if comp.Metadata["key2"] != "val2" {
		t.Errorf("Metadata[key2] = %q, want %q", comp.Metadata["key2"], "val2")
	}
}

func TestComponentCopy(t *testing.T) {
	original := &ComponentStatus{
		Name:         "test",
		State:        StateHealthy,
		Dependencies: []string{"a", "b"},
		Metadata:     map[string]string{"key": "val"},
	}
	copy := original.Copy()
	copy.Name = "modified"
	copy.Dependencies[0] = "modified"
	copy.Metadata["key"] = "modified"

	if original.Name != "test" {
		t.Error("Copy should not modify original Name")
	}
	if original.Dependencies[0] != "a" {
		t.Error("Copy should not modify original Dependencies")
	}
	if original.Metadata["key"] != "val" {
		t.Error("Copy should not modify original Metadata")
	}
}
