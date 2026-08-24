package events

import (
	"fmt"
	"sync"
	"time"
)

type Type string

const (
	EventDeployStarted      Type = "deploy.started"
	EventDeployCompleted    Type = "deploy.completed"
	EventDeployFailed       Type = "deploy.failed"
	EventRollbackStarted    Type = "rollback.started"
	EventRollbackCompleted  Type = "rollback.completed"
	EventRollbackFailed     Type = "rollback.failed"
	EventReconcileStarted   Type = "reconcile.started"
	EventReconcileCompleted Type = "reconcile.completed"
	EventReconcileFailed    Type = "reconcile.failed"
	EventUpdateStarted      Type = "update.started"
	EventUpdateCompleted    Type = "update.completed"
	EventUpdateFailed       Type = "update.failed"
	EventBackupStarted      Type = "backup.started"
	EventBackupCompleted    Type = "backup.completed"
	EventBackupFailed       Type = "backup.failed"
	EventRestoreStarted     Type = "restore.started"
	EventRestoreCompleted   Type = "restore.completed"
	EventRestoreFailed      Type = "restore.failed"
	EventHealthCheckFailed  Type = "health.failed"
	EventHealthCheckPassed  Type = "health.passed"
	EventServiceDown        Type = "service.down"
	EventServiceRecovered   Type = "service.recovered"
	EventSecretUpdated      Type = "secret.updated"
	EventAITaskCreated      Type = "ai.task.created"
	EventAITaskCompleted    Type = "ai.task.completed"
	EventAITaskFailed       Type = "ai.task.failed"
	EventOpenCodeTask       Type = "opencode.task"
	EventBuildStarted       Type = "build.started"
	EventBuildCompleted     Type = "build.completed"
	EventBuildFailed        Type = "build.failed"
	EventPluginLoaded       Type = "plugin.loaded"
	EventPluginFailed       Type = "plugin.failed"
)

func (t Type) String() string { return string(t) }

type Severity string

const (
	SeverityInfo     Severity = "info"
	SeverityWarn     Severity = "warn"
	SeverityError    Severity = "error"
	SeverityCritical Severity = "critical"
)

type Event struct {
	ID        string
	Type      Type
	Source    string
	Timestamp time.Time
	Severity  Severity
	Message   string
	Metadata  map[string]string
}

func (e Event) String() string {
	return fmt.Sprintf("[%s] %s/%s: %s", e.Timestamp.Format(time.RFC3339), e.Source, e.Type, e.Message)
}

type Subscriber interface {
	Name() string
	Handle(event Event)
}

type SubscriberFunc struct {
	name string
	fn   func(Event)
}

func NewSubscriber(name string, fn func(Event)) *SubscriberFunc {
	return &SubscriberFunc{name: name, fn: fn}
}

func (s *SubscriberFunc) Name() string       { return s.name }
func (s *SubscriberFunc) Handle(event Event) { s.fn(event) }

type Bus struct {
	subscribers []Subscriber
	mu          sync.RWMutex
	eventID     int64
	history     []Event
	historyCap  int
}

func New() *Bus {
	return &Bus{historyCap: 100}
}

func NewWithHistory(capacity int) *Bus {
	if capacity <= 0 {
		capacity = 100
	}
	return &Bus{historyCap: capacity}
}

func (b *Bus) Subscribe(sub Subscriber) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.subscribers = append(b.subscribers, sub)
}

func (b *Bus) SubscribeFunc(name string, fn func(Event)) {
	b.Subscribe(NewSubscriber(name, fn))
}

func (b *Bus) Unsubscribe(name string) {
	b.mu.Lock()
	defer b.mu.Unlock()
	filtered := make([]Subscriber, 0, len(b.subscribers))
	for _, s := range b.subscribers {
		if s.Name() != name {
			filtered = append(filtered, s)
		}
	}
	b.subscribers = filtered
}

func (b *Bus) Emit(eventType Type, source, message string, severity Severity, metadata map[string]string) {
	b.mu.Lock()
	b.eventID++
	id := fmt.Sprintf("%d", b.eventID)
	subs := make([]Subscriber, len(b.subscribers))
	copy(subs, b.subscribers)
	b.mu.Unlock()

	event := Event{
		ID:        id,
		Type:      eventType,
		Source:    source,
		Timestamp: time.Now(),
		Severity:  severity,
		Message:   message,
		Metadata:  metadata,
	}

	b.recordHistory(event)

	for _, sub := range subs {
		sub.Handle(event)
	}
}

func (b *Bus) recordHistory(event Event) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.history = append(b.history, event)
	if len(b.history) > b.historyCap {
		b.history = b.history[len(b.history)-b.historyCap:]
	}
}

func (b *Bus) History() []Event {
	b.mu.RLock()
	defer b.mu.RUnlock()
	out := make([]Event, len(b.history))
	copy(out, b.history)
	return out
}

func (b *Bus) HistoryLast(n int) []Event {
	b.mu.RLock()
	defer b.mu.RUnlock()
	if n <= 0 || n > len(b.history) {
		n = len(b.history)
	}
	out := make([]Event, n)
	copy(out, b.history[len(b.history)-n:])
	return out
}

func (b *Bus) HistoryByType(eventType Type) []Event {
	b.mu.RLock()
	defer b.mu.RUnlock()
	var out []Event
	for _, e := range b.history {
		if e.Type == eventType {
			out = append(out, e)
		}
	}
	return out
}

func (b *Bus) HistoryBySeverity(severity Severity) []Event {
	b.mu.RLock()
	defer b.mu.RUnlock()
	var out []Event
	for _, e := range b.history {
		if e.Severity == severity {
			out = append(out, e)
		}
	}
	return out
}

func (b *Bus) HistoryCount() int {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return len(b.history)
}

func (b *Bus) EmitDeployStarted(source string, metadata map[string]string) {
	b.Emit(EventDeployStarted, source, "deployment started", SeverityInfo, metadata)
}

func (b *Bus) EmitDeployCompleted(source string, metadata map[string]string) {
	b.Emit(EventDeployCompleted, source, "deployment completed successfully", SeverityInfo, metadata)
}

func (b *Bus) EmitDeployFailed(source string, err error, metadata map[string]string) {
	m := metadata
	if m == nil {
		m = make(map[string]string)
	}
	errMsg := "unknown error"
	if err != nil {
		errMsg = err.Error()
	}
	m["error"] = errMsg
	b.Emit(EventDeployFailed, source, fmt.Sprintf("deployment failed: %s", errMsg), SeverityError, m)
}

func (b *Bus) EmitRollbackStarted(source string, metadata map[string]string) {
	b.Emit(EventRollbackStarted, source, "rollback started", SeverityWarn, metadata)
}

func (b *Bus) EmitRollbackCompleted(source string, metadata map[string]string) {
	b.Emit(EventRollbackCompleted, source, "rollback completed", SeverityInfo, metadata)
}

func (b *Bus) EmitHealthFailed(source string, message string, metadata map[string]string) {
	b.Emit(EventHealthCheckFailed, source, message, SeverityWarn, metadata)
}

func (b *Bus) EmitHealthPassed(source string, metadata map[string]string) {
	b.Emit(EventHealthCheckPassed, source, "health check passed", SeverityInfo, metadata)
}

func (b *Bus) EmitServiceDown(source, service string, metadata map[string]string) {
	m := metadata
	if m == nil {
		m = make(map[string]string)
	}
	m["service"] = service
	b.Emit(EventServiceDown, source, fmt.Sprintf("service down: %s", service), SeverityError, m)
}

func (b *Bus) EmitServiceRecovered(source, service string, metadata map[string]string) {
	m := metadata
	if m == nil {
		m = make(map[string]string)
	}
	m["service"] = service
	b.Emit(EventServiceRecovered, source, fmt.Sprintf("service recovered: %s", service), SeverityInfo, m)
}

func (b *Bus) EmitAITaskCreated(source, taskID string, metadata map[string]string) {
	m := metadata
	if m == nil {
		m = make(map[string]string)
	}
	m["task_id"] = taskID
	b.Emit(EventAITaskCreated, source, fmt.Sprintf("AI task created: %s", taskID), SeverityInfo, m)
}

func (b *Bus) EmitAITaskCompleted(source, taskID string, metadata map[string]string) {
	m := metadata
	if m == nil {
		m = make(map[string]string)
	}
	m["task_id"] = taskID
	b.Emit(EventAITaskCompleted, source, fmt.Sprintf("AI task completed: %s", taskID), SeverityInfo, m)
}

func (b *Bus) EmitPluginLoaded(source string, err error) {
	m := make(map[string]string)
	if err != nil {
		m["error"] = err.Error()
		b.Emit(EventPluginFailed, source, fmt.Sprintf("plugin failed: %s", err), SeverityError, m)
		return
	}
	b.Emit(EventPluginLoaded, source, fmt.Sprintf("plugin loaded: %s", source), SeverityInfo, m)
}

func (b *Bus) EmitPluginFailed(source string, err error) {
	m := make(map[string]string)
	errMsg := "unknown error"
	if err != nil {
		errMsg = err.Error()
	}
	m["error"] = errMsg
	b.Emit(EventPluginFailed, source, fmt.Sprintf("plugin failed: %s", errMsg), SeverityError, m)
}

func (b *Bus) SubscriberCount() int {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return len(b.subscribers)
}
