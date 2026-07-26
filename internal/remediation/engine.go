package remediation

import (
	"fmt"
	"sync"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

type Action interface {
	Name() string
	CanFix(comp *state.ComponentStatus) bool
	Fix(comp *state.ComponentStatus) (*Result, error)
}

type Result struct {
	Success   bool
	Message   string
	Duration  time.Duration
	Timestamp time.Time
}

type Engine struct {
	state   *state.Engine
	events  *events.Bus
	actions []Action
	mu      sync.RWMutex
	running bool
	history []ActionResult
	maxHist int
}

type ActionResult struct {
	Action    string
	Component string
	Result    *Result
	Error     error
	Timestamp time.Time
}

func NewEngine(state *state.Engine, events *events.Bus) *Engine {
	return &Engine{
		state:   state,
		events:  events,
		actions: make([]Action, 0),
		maxHist: 100,
	}
}

func (e *Engine) RegisterAction(action Action) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.actions = append(e.actions, action)
}

func (e *Engine) Start() {
	e.mu.Lock()
	if e.running {
		e.mu.Unlock()
		return
	}
	e.running = true
	e.mu.Unlock()

	e.state.Subscribe(func(name string, old, new state.State) {
		if new == state.StateDegraded || new == state.StateOffline {
			go e.attemptRemediation(name)
		}
	})

	if e.events != nil {
		e.events.SubscribeFunc("remediation-engine", func(evt events.Event) {
			if evt.Severity == events.SeverityError || evt.Severity == events.SeverityCritical {
				go e.handleEvent(evt)
			}
		})
	}
}

func (e *Engine) Stop() {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.running = false
}

func (e *Engine) attemptRemediation(componentName string) {
	comp, ok := e.state.Get(componentName)
	if !ok {
		return
	}

	e.mu.RLock()
	actions := make([]Action, len(e.actions))
	copy(actions, e.actions)
	e.mu.RUnlock()

	for _, action := range actions {
		if action.CanFix(&comp) {
			start := time.Now()
			result, err := action.Fix(&comp)
			duration := time.Since(start)

			ar := ActionResult{
				Action:    action.Name(),
				Component: componentName,
				Result:    result,
				Error:     err,
				Timestamp: time.Now(),
			}

			e.recordHistory(ar)

			if err == nil && result != nil && result.Success {
				e.state.Set(componentName, state.StateHealthy, fmt.Sprintf("auto-fixed by %s", action.Name()))
				if e.events != nil {
					e.events.Emit(
						events.Type("remediation.completed"),
						"remediation-engine",
						fmt.Sprintf("component %s auto-fixed by %s", componentName, action.Name()),
						events.SeverityInfo,
						map[string]string{
							"component": componentName,
							"action":    action.Name(),
							"duration":  duration.String(),
						},
					)
				}
				return
			}
		}
	}
}

func (e *Engine) handleEvent(evt events.Event) {
	if e.events == nil {
		return
	}

	e.mu.RLock()
	actions := make([]Action, len(e.actions))
	copy(actions, e.actions)
	e.mu.RUnlock()

	for _, action := range actions {
		if action.CanFix(nil) {
			start := time.Now()
			result, err := action.Fix(nil)
			duration := time.Since(start)

			ar := ActionResult{
				Action:    action.Name(),
				Component: evt.Source,
				Result:    result,
				Error:     err,
				Timestamp: time.Now(),
			}

			e.recordHistory(ar)

			if err == nil && result != nil && result.Success {
				e.events.Emit(
					events.Type("remediation.completed"),
					"remediation-engine",
					fmt.Sprintf("event %s handled by %s", evt.Type, action.Name()),
					events.SeverityInfo,
					map[string]string{
						"event_type": string(evt.Type),
						"action":     action.Name(),
						"duration":   duration.String(),
					},
				)
				return
			}
		}
	}
}

func (e *Engine) recordHistory(ar ActionResult) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.history = append(e.history, ar)
	if len(e.history) > e.maxHist {
		e.history = e.history[len(e.history)-e.maxHist:]
	}
}

func (e *Engine) History() []ActionResult {
	e.mu.RLock()
	defer e.mu.RUnlock()
	out := make([]ActionResult, len(e.history))
	copy(out, e.history)
	return out
}

func (e *Engine) HistoryLast(n int) []ActionResult {
	e.mu.RLock()
	defer e.mu.RUnlock()
	if n <= 0 || n > len(e.history) {
		n = len(e.history)
	}
	out := make([]ActionResult, n)
	copy(out, e.history[len(e.history)-n:])
	return out
}

func (e *Engine) ActionCount() int {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return len(e.actions)
}
