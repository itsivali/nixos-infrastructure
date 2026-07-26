package monitor

import (
	"fmt"
	"sync"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/platform/health"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

type CheckFunc func() (*CheckResult, error)

type CheckResult struct {
	Name    string
	State   state.State
	Message string
}

type Monitor struct {
	state    *state.Engine
	events   *events.Bus
	checks   map[string]CheckFunc
	interval time.Duration
	mu       sync.RWMutex
	running  bool
	stopCh   chan struct{}
}

func New(state *state.Engine, events *events.Bus, interval time.Duration) *Monitor {
	return &Monitor{
		state:    state,
		events:   events,
		checks:   make(map[string]CheckFunc),
		interval: interval,
		stopCh:   make(chan struct{}),
	}
}

func (m *Monitor) RegisterCheck(name string, check CheckFunc) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.checks[name] = check
	m.state.Register(name, name, "health-check")
}

func (m *Monitor) Start() {
	m.mu.Lock()
	if m.running {
		m.mu.Unlock()
		return
	}
	m.running = true
	m.mu.Unlock()

	go m.loop()
}

func (m *Monitor) Stop() {
	m.mu.Lock()
	defer m.mu.Unlock()
	if !m.running {
		return
	}
	m.running = false
	close(m.stopCh)
}

func (m *Monitor) loop() {
	m.runChecks()
	ticker := time.NewTicker(m.interval)
	defer ticker.Stop()

	for {
		select {
		case <-m.stopCh:
			return
		case <-ticker.C:
			m.runChecks()
		}
	}
}

func (m *Monitor) runChecks() {
	m.mu.RLock()
	checks := make(map[string]CheckFunc)
	for k, v := range m.checks {
		checks[k] = v
	}
	m.mu.RUnlock()

	for name, check := range checks {
		result, err := check()
		if err != nil {
			m.state.Set(name, state.StateDegraded, fmt.Sprintf("check error: %v", err))
			if m.events != nil {
				m.events.EmitHealthFailed("monitor", fmt.Sprintf("%s check failed: %v", name, err), nil)
			}
			continue
		}

		oldComp, _ := m.state.Get(name)
		oldState := oldComp.State
		m.state.Set(name, result.State, result.Message)

		if oldState != result.State && m.events != nil {
			if result.State == state.StateHealthy {
				m.events.EmitHealthPassed("monitor", nil)
			} else if result.State == state.StateDegraded || result.State == state.StateOffline {
				m.events.EmitHealthFailed("monitor", fmt.Sprintf("%s: %s", name, result.Message), nil)
			}
		}
	}
}

func adaptCheck(r health.CheckResult) *CheckResult {
	return &CheckResult{Name: r.Name, State: r.State, Message: r.Message}
}

func CheckDisk() (*CheckResult, error) {
	return adaptCheck(health.CheckDisk()), nil
}

func CheckMemory() (*CheckResult, error) {
	return adaptCheck(health.CheckMemory()), nil
}

func CheckLoad() (*CheckResult, error) {
	return adaptCheck(health.CheckCPULoad()), nil
}

func CheckService(name string) CheckFunc {
	return func() (*CheckResult, error) {
		return adaptCheck(health.CheckService(name)), nil
	}
}
