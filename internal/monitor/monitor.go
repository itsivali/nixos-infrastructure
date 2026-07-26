package monitor

import (
	"fmt"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/events"
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

func CheckDisk() (*CheckResult, error) {
	out, err := exec.Command("sh", "-c", "df -h / | tail -1 | awk '{print $5}' | tr -d '%'").CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("checking disk: %w", err)
	}

	percent := strings.TrimSpace(string(out))
	var used int
	_, _ = fmt.Sscanf(percent, "%d", &used)

	if used > 90 {
		return &CheckResult{
			Name:    "disk",
			State:   state.StateDegraded,
			Message: fmt.Sprintf("disk usage critical: %s%%", percent),
		}, nil
	}
	if used > 80 {
		return &CheckResult{
			Name:    "disk",
			State:   state.StateWarning,
			Message: fmt.Sprintf("disk usage high: %s%%", percent),
		}, nil
	}

	return &CheckResult{
		Name:    "disk",
		State:   state.StateHealthy,
		Message: fmt.Sprintf("disk usage normal: %s%%", percent),
	}, nil
}

func CheckMemory() (*CheckResult, error) {
	out, err := exec.Command("sh", "-c", "free | grep Mem | awk '{printf \"%.0f\", $3/$2 * 100}'").CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("checking memory: %w", err)
	}

	percent := strings.TrimSpace(string(out))
	var used int
	_, _ = fmt.Sscanf(percent, "%d", &used)

	if used > 95 {
		return &CheckResult{
			Name:    "memory",
			State:   state.StateDegraded,
			Message: fmt.Sprintf("memory usage critical: %s%%", percent),
		}, nil
	}
	if used > 85 {
		return &CheckResult{
			Name:    "memory",
			State:   state.StateWarning,
			Message: fmt.Sprintf("memory usage high: %s%%", percent),
		}, nil
	}

	return &CheckResult{
		Name:    "memory",
		State:   state.StateHealthy,
		Message: fmt.Sprintf("memory usage normal: %s%%", percent),
	}, nil
}

func CheckLoad() (*CheckResult, error) {
	out, err := exec.Command("sh", "-c", "cat /proc/loadavg | awk '{print $1}'").CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("checking load: %w", err)
	}

	loadStr := strings.TrimSpace(string(out))
	var load float64
	_, _ = fmt.Sscanf(loadStr, "%f", &load)

	cpusOut, _ := exec.Command("nproc").CombinedOutput()
	var cpus int
	_, _ = fmt.Sscanf(strings.TrimSpace(string(cpusOut)), "%d", &cpus)
	if cpus == 0 {
		cpus = 1
	}

	ratio := load / float64(cpus)
	if ratio > 2.0 {
		return &CheckResult{
			Name:    "load",
			State:   state.StateDegraded,
			Message: fmt.Sprintf("load critical: %s (%.1fx cores)", loadStr, ratio),
		}, nil
	}
	if ratio > 1.5 {
		return &CheckResult{
			Name:    "load",
			State:   state.StateWarning,
			Message: fmt.Sprintf("load high: %s (%.1fx cores)", loadStr, ratio),
		}, nil
	}

	return &CheckResult{
		Name:    "load",
		State:   state.StateHealthy,
		Message: fmt.Sprintf("load normal: %s", loadStr),
	}, nil
}

func CheckService(name string) CheckFunc {
	return func() (*CheckResult, error) {
		out, err := exec.Command("systemctl", "is-active", name).CombinedOutput()
		status := strings.TrimSpace(string(out))

		if err != nil || status != "active" {
			return &CheckResult{
				Name:    name,
				State:   state.StateDegraded,
				Message: fmt.Sprintf("service %s is %s", name, status),
			}, nil
		}

		return &CheckResult{
			Name:    name,
			State:   state.StateHealthy,
			Message: fmt.Sprintf("service %s is active", name),
		}, nil
	}
}
