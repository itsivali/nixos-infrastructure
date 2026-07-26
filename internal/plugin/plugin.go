package plugin

import (
	"fmt"
	"sort"
	"strings"
	"sync"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

type Plugin interface {
	Name() string
	DisplayName() string
	Dependencies() []string
	Init(engine *state.Engine, bus *events.Bus) error
	Status() *state.ComponentStatus
	Shutdown() error
}

type BasePlugin struct {
	displayName string
	deps        []string
}

func NewBase(displayName string, deps ...string) BasePlugin {
	return BasePlugin{displayName: displayName, deps: deps}
}

func (b BasePlugin) DisplayName() string    { return b.displayName }
func (b BasePlugin) Dependencies() []string { return b.deps }

type Registry struct {
	plugins map[string]Plugin
	engine  *state.Engine
	bus     *events.Bus
	mu      sync.RWMutex
}

func NewRegistry(engine *state.Engine, bus *events.Bus) *Registry {
	return &Registry{
		plugins: make(map[string]Plugin),
		engine:  engine,
		bus:     bus,
	}
}

func (r *Registry) Register(plugin Plugin) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	name := plugin.Name()
	if _, exists := r.plugins[name]; exists {
		return fmt.Errorf("plugin %q already registered", name)
	}

	r.plugins[name] = plugin

	for _, dep := range plugin.Dependencies() {
		if _, exists := r.plugins[dep]; !exists {
			return fmt.Errorf("plugin %q depends on %q which is not registered", name, dep)
		}
	}

	r.engine.Register(name, plugin.DisplayName(), "plugin")
	r.engine.SetDetail(name,
		state.WithDependencies(plugin.Dependencies()),
	)

	return nil
}

func (r *Registry) InitAll() []error {
	r.mu.RLock()
	names := make([]string, 0, len(r.plugins))
	for name := range r.plugins {
		names = append(names, name)
	}
	r.mu.RUnlock()

	sort.Strings(names)

	var errs []error
	for _, name := range names {
		r.mu.RLock()
		p := r.plugins[name]
		r.mu.RUnlock()

		if err := p.Init(r.engine, r.bus); err != nil {
			errs = append(errs, fmt.Errorf("plugin %q: %w", name, err))
			r.engine.Set(name, state.StateDegraded, fmt.Sprintf("init failed: %s", err))
			if r.bus != nil {
				r.bus.EmitPluginFailed(name, err)
			}
		} else {
			r.engine.Set(name, state.StateHealthy, fmt.Sprintf("plugin %q initialized", name))
			if r.bus != nil {
				r.bus.EmitPluginLoaded(name, nil)
			}
		}
	}
	return errs
}

func (r *Registry) Get(name string) (Plugin, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	p, ok := r.plugins[name]
	return p, ok
}

func (r *Registry) All() []Plugin {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]Plugin, 0, len(r.plugins))
	for _, p := range r.plugins {
		result = append(result, p)
	}
	sort.Slice(result, func(i, j int) bool {
		return result[i].Name() < result[j].Name()
	})
	return result
}

func (r *Registry) PluginCount() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.plugins)
}

func (r *Registry) List() string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var b strings.Builder
	names := make([]string, 0, len(r.plugins))
	for name := range r.plugins {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		p := r.plugins[name]
		comp, ok := r.engine.Get(name)
		stateStr := "unknown"
		if ok {
			stateStr = comp.State.String()
		}
		b.WriteString(fmt.Sprintf("  %s (%s) [%s]\n", name, p.DisplayName(), stateStr))
	}
	return b.String()
}

func (r *Registry) StatusAll() map[string]*state.ComponentStatus {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make(map[string]*state.ComponentStatus, len(r.plugins))
	for name, p := range r.plugins {
		s := p.Status()
		if s != nil {
			result[name] = s
		}
	}
	return result
}

func (r *Registry) ShutdownAll() []error {
	r.mu.RLock()
	names := make([]string, 0, len(r.plugins))
	for name := range r.plugins {
		names = append(names, name)
	}
	r.mu.RUnlock()

	sort.Sort(sort.Reverse(sort.StringSlice(names)))

	var errs []error
	for _, name := range names {
		r.mu.RLock()
		p := r.plugins[name]
		r.mu.RUnlock()

		if err := p.Shutdown(); err != nil {
			errs = append(errs, fmt.Errorf("plugin %q shutdown: %w", name, err))
		}
	}
	return errs
}
