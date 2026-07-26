package state

import (
	"fmt"
	"sort"
	"sync"
	"time"
)

type State int

const (
	StateHealthy State = iota
	StateWarning
	StateDegraded
	StateOffline
	StateUnknown
)

func (s State) String() string {
	switch s {
	case StateHealthy:
		return "healthy"
	case StateWarning:
		return "warning"
	case StateDegraded:
		return "degraded"
	case StateOffline:
		return "offline"
	case StateUnknown:
		return "unknown"
	default:
		return "unknown"
	}
}

func (s State) MarshalText() ([]byte, error) {
	return []byte(s.String()), nil
}

func ParseState(s string) State {
	switch s {
	case "healthy":
		return StateHealthy
	case "warning":
		return StateWarning
	case "degraded":
		return StateDegraded
	case "offline":
		return StateOffline
	default:
		return StateUnknown
	}
}

type ComponentStatus struct {
	Name           string
	DisplayName    string
	Kind           string
	State          State
	Message        string
	Version        string
	LastSuccess    time.Time
	LastFailure    time.Time
	LastValidation time.Time
	ErrorCount     int
	Dependencies   []string
	Metadata       map[string]string
}

func (c *ComponentStatus) Copy() ComponentStatus {
	deps := make([]string, len(c.Dependencies))
	copy(deps, c.Dependencies)
	meta := make(map[string]string, len(c.Metadata))
	for k, v := range c.Metadata {
		meta[k] = v
	}
	return ComponentStatus{
		Name:           c.Name,
		DisplayName:    c.DisplayName,
		Kind:           c.Kind,
		State:          c.State,
		Message:        c.Message,
		Version:        c.Version,
		LastSuccess:    c.LastSuccess,
		LastFailure:    c.LastFailure,
		LastValidation: c.LastValidation,
		ErrorCount:     c.ErrorCount,
		Dependencies:   deps,
		Metadata:       meta,
	}
}

type ChangeListener func(name string, old, new State)

type Engine struct {
	components map[string]*ComponentStatus
	listeners  []ChangeListener
	mu         sync.RWMutex
}

func New() *Engine {
	return &Engine{
		components: make(map[string]*ComponentStatus),
	}
}

func (e *Engine) Register(name, displayName, kind string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if _, exists := e.components[name]; exists {
		return
	}
	e.components[name] = &ComponentStatus{
		Name:        name,
		DisplayName: displayName,
		Kind:        kind,
		State:       StateUnknown,
		Metadata:    make(map[string]string),
	}
}

func (e *Engine) Set(name string, state State, message string) {
	e.mu.Lock()
	comp, exists := e.components[name]
	if !exists {
		comp = &ComponentStatus{
			Name:     name,
			Kind:     "dynamic",
			Metadata: make(map[string]string),
		}
		e.components[name] = comp
	}
	old := comp.State
	comp.State = state
	comp.Message = message
	comp.LastValidation = time.Now()
	if state == StateHealthy || state == StateWarning {
		comp.LastSuccess = time.Now()
		comp.ErrorCount = 0
	} else if state == StateDegraded || state == StateOffline {
		comp.LastFailure = time.Now()
		comp.ErrorCount++
	}
	listeners := make([]ChangeListener, len(e.listeners))
	copy(listeners, e.listeners)
	e.mu.Unlock()

	for _, l := range listeners {
		l(name, old, state)
	}
}

func (e *Engine) SetDetail(name string, opts ...DetailOption) {
	e.mu.Lock()
	defer e.mu.Unlock()
	comp, exists := e.components[name]
	if !exists {
		comp = &ComponentStatus{
			Name:     name,
			Kind:     "dynamic",
			Metadata: make(map[string]string),
		}
		e.components[name] = comp
	}
	for _, opt := range opts {
		opt(comp)
	}
}

type DetailOption func(*ComponentStatus)

func WithVersion(v string) DetailOption {
	return func(c *ComponentStatus) { c.Version = v }
}

func WithDisplayName(n string) DetailOption {
	return func(c *ComponentStatus) { c.DisplayName = n }
}

func WithKind(k string) DetailOption {
	return func(c *ComponentStatus) { c.Kind = k }
}

func WithDependency(d string) DetailOption {
	return func(c *ComponentStatus) { c.Dependencies = append(c.Dependencies, d) }
}

func WithDependencies(deps []string) DetailOption {
	return func(c *ComponentStatus) { c.Dependencies = deps }
}

func WithMeta(k, v string) DetailOption {
	return func(c *ComponentStatus) {
		if c.Metadata == nil {
			c.Metadata = make(map[string]string)
		}
		c.Metadata[k] = v
	}
}

func WithMetaMap(m map[string]string) DetailOption {
	return func(c *ComponentStatus) {
		if c.Metadata == nil {
			c.Metadata = make(map[string]string)
		}
		for k, v := range m {
			c.Metadata[k] = v
		}
	}
}

func (e *Engine) Subscribe(listener ChangeListener) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.listeners = append(e.listeners, listener)
}

func (e *Engine) Get(name string) (ComponentStatus, bool) {
	e.mu.RLock()
	defer e.mu.RUnlock()
	comp, ok := e.components[name]
	if !ok {
		return ComponentStatus{}, false
	}
	return comp.Copy(), true
}

func (e *Engine) ComponentCount() int {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return len(e.components)
}

func (e *Engine) All() map[string]ComponentStatus {
	e.mu.RLock()
	defer e.mu.RUnlock()
	result := make(map[string]ComponentStatus, len(e.components))
	for name, comp := range e.components {
		result[name] = comp.Copy()
	}
	return result
}

func (e *Engine) ByState(s State) []ComponentStatus {
	e.mu.RLock()
	defer e.mu.RUnlock()
	var result []ComponentStatus
	for _, comp := range e.components {
		if comp.State == s {
			result = append(result, comp.Copy())
		}
	}
	sort.Slice(result, func(i, j int) bool {
		return result[i].Name < result[j].Name
	})
	return result
}

func (e *Engine) NonHealthy() []ComponentStatus {
	e.mu.RLock()
	defer e.mu.RUnlock()
	var result []ComponentStatus
	for _, comp := range e.components {
		if comp.State != StateHealthy && comp.State != StateUnknown {
			result = append(result, comp.Copy())
		}
	}
	sort.Slice(result, func(i, j int) bool {
		return result[i].Name < result[j].Name
	})
	return result
}

func (e *Engine) GlobalState() State {
	e.mu.RLock()
	defer e.mu.RUnlock()
	hasWarning := false
	for _, comp := range e.components {
		switch comp.State {
		case StateDegraded, StateOffline:
			return comp.State
		case StateWarning:
			hasWarning = true
		}
	}
	if hasWarning {
		return StateWarning
	}
	if len(e.components) == 0 {
		return StateUnknown
	}
	return StateHealthy
}

func (e *Engine) Summary() string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	healthy := 0
	warning := 0
	degraded := 0
	offline := 0
	unknown := 0
	for _, comp := range e.components {
		switch comp.State {
		case StateHealthy:
			healthy++
		case StateWarning:
			warning++
		case StateDegraded:
			degraded++
		case StateOffline:
			offline++
		default:
			unknown++
		}
	}
	return fmt.Sprintf("%d healthy, %d warning, %d degraded, %d offline, %d unknown (total: %d)",
		healthy, warning, degraded, offline, unknown, len(e.components))
}
