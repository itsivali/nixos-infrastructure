package events

import (
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"
)

func TestBusEmitAndSubscribe(t *testing.T) {
	b := New()
	var mu sync.Mutex
	var received []Event

	b.SubscribeFunc("test", func(event Event) {
		mu.Lock()
		received = append(received, event)
		mu.Unlock()
	})

	b.Emit(EventDeployStarted, "test-source", "test message", SeverityInfo, nil)

	if len(received) != 1 {
		t.Fatalf("expected 1 event, got %d", len(received))
	}
	if received[0].Type != EventDeployStarted {
		t.Errorf("Type = %v, want %v", received[0].Type, EventDeployStarted)
	}
	if received[0].Source != "test-source" {
		t.Errorf("Source = %q, want %q", received[0].Source, "test-source")
	}
	if received[0].Message != "test message" {
		t.Errorf("Message = %q, want %q", received[0].Message, "test message")
	}
	if received[0].Severity != SeverityInfo {
		t.Errorf("Severity = %v, want %v", received[0].Severity, SeverityInfo)
	}
	if received[0].Timestamp.IsZero() {
		t.Error("expected non-zero timestamp")
	}
	if received[0].ID == "" {
		t.Error("expected non-empty ID")
	}
}

func TestBusMultipleSubscribers(t *testing.T) {
	b := New()
	count1 := 0
	count2 := 0

	b.SubscribeFunc("sub1", func(event Event) { count1++ })
	b.SubscribeFunc("sub2", func(event Event) { count2++ })

	b.Emit(EventDeployCompleted, "src", "msg", SeverityInfo, nil)

	if count1 != 1 {
		t.Errorf("sub1 count = %d, want 1", count1)
	}
	if count2 != 1 {
		t.Errorf("sub2 count = %d, want 1", count2)
	}
}

func TestBusUnsubscribe(t *testing.T) {
	b := New()
	count := 0

	b.SubscribeFunc("test", func(event Event) { count++ })
	b.Emit(EventReconcileStarted, "src", "msg", SeverityInfo, nil)

	if count != 1 {
		t.Errorf("count = %d, want 1", count)
	}

	b.Unsubscribe("test")
	b.Emit(EventReconcileCompleted, "src", "msg", SeverityInfo, nil)

	if count != 1 {
		t.Errorf("count after unsubscribe = %d, want 1 (no change)", count)
	}
}

func TestBusConvenienceMethods(t *testing.T) {
	b := New()
	var mu sync.Mutex
	var events []Event

	b.SubscribeFunc("recorder", func(event Event) {
		mu.Lock()
		events = append(events, event)
		mu.Unlock()
	})

	b.EmitDeployStarted("test", nil)
	b.EmitDeployCompleted("test", nil)
	b.EmitDeployFailed("test", nil, nil)
	b.EmitRollbackStarted("test", nil)
	b.EmitRollbackCompleted("test", nil)
	b.EmitHealthFailed("test", "disk full", nil)
	b.EmitHealthPassed("test", nil)
	b.EmitServiceDown("test", "nginx", nil)
	b.EmitServiceRecovered("test", "nginx", nil)

	if len(events) != 9 {
		t.Fatalf("expected 9 events, got %d", len(events))
	}

	expectedTypes := []Type{
		EventDeployStarted,
		EventDeployCompleted,
		EventDeployFailed,
		EventRollbackStarted,
		EventRollbackCompleted,
		EventHealthCheckFailed,
		EventHealthCheckPassed,
		EventServiceDown,
		EventServiceRecovered,
	}

	for i, et := range expectedTypes {
		if events[i].Type != et {
			t.Errorf("event[%d] Type = %v, want %v", i, events[i].Type, et)
		}
	}

	if events[2].Metadata["error"] != "unknown error" {
		t.Errorf("expected error metadata in deploy failed, got %q", events[2].Metadata["error"])
	}
}

func TestBusMetadata(t *testing.T) {
	b := New()
	var received Event

	b.SubscribeFunc("test", func(event Event) {
		received = event
	})

	meta := map[string]string{
		"host":   "prague",
		"task":   "abc-123",
		"result": "success",
	}
	b.Emit(EventJulesTaskCreated, "jules", "task created", SeverityInfo, meta)

	if received.Metadata["host"] != "prague" {
		t.Errorf("Metadata[host] = %q, want %q", received.Metadata["host"], "prague")
	}
	if received.Metadata["task"] != "abc-123" {
		t.Errorf("Metadata[task] = %q, want %q", received.Metadata["task"], "abc-123")
	}
}

func TestBusDeployFailedWithError(t *testing.T) {
	b := New()
	var received Event
	b.SubscribeFunc("test", func(event Event) { received = event })

	err := errors.New("deploy failed")
	b.EmitDeployFailed("test", err, map[string]string{"host": "prague"})

	if received.Metadata["error"] != err.Error() {
		t.Errorf("Metadata[error] = %q, want %q", received.Metadata["error"], err.Error())
	}
	if received.Metadata["host"] != "prague" {
		t.Errorf("Metadata[host] = %q, want %q", received.Metadata["host"], "prague")
	}
}

func TestBusSubscriberCount(t *testing.T) {
	b := New()
	if b.SubscriberCount() != 0 {
		t.Errorf("expected 0 subscribers, got %d", b.SubscriberCount())
	}

	b.SubscribeFunc("a", func(Event) {})
	b.SubscribeFunc("b", func(Event) {})

	if b.SubscriberCount() != 2 {
		t.Errorf("expected 2 subscribers, got %d", b.SubscriberCount())
	}

	b.Unsubscribe("a")
	if b.SubscriberCount() != 1 {
		t.Errorf("expected 1 subscriber, got %d", b.SubscriberCount())
	}
}

func TestBusConcurrent(t *testing.T) {
	b := New()
	var mu sync.Mutex
	count := 0

	b.SubscribeFunc("test", func(event Event) {
		mu.Lock()
		count++
		mu.Unlock()
	})

	var wg sync.WaitGroup
	for i := 0; i < 100; i++ {
		wg.Add(1)
		func() {
			defer wg.Done()
			b.Emit(EventBuildStarted, "test", "build", SeverityInfo, nil)
		}()
	}
	wg.Wait()

	if count != 100 {
		t.Errorf("expected 100 events, got %d", count)
	}
}

func TestSubscriberFunc(t *testing.T) {
	called := false
	sf := NewSubscriber("test", func(event Event) {
		called = true
	})
	if sf.Name() != "test" {
		t.Errorf("Name = %q, want %q", sf.Name(), "test")
	}
	sf.Handle(Event{})
	if !called {
		t.Error("expected handler to be called")
	}
}

func TestEventString(t *testing.T) {
	e := Event{
		Type:      EventDeployStarted,
		Source:    "cli",
		Timestamp: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		Message:   "deploy started",
	}
	s := e.String()
	if s == "" {
		t.Error("expected non-empty string")
	}
}

func TestTypeString(t *testing.T) {
	if got := EventDeployStarted.String(); got != "deploy.started" {
		t.Errorf("Type.String() = %q, want %q", got, "deploy.started")
	}
}

func TestBusHistory(t *testing.T) {
	b := NewWithHistory(5)

	b.Emit(EventDeployStarted, "src", "msg1", SeverityInfo, nil)
	b.Emit(EventDeployCompleted, "src", "msg2", SeverityInfo, nil)
	b.Emit(EventHealthCheckFailed, "src", "msg3", SeverityWarn, nil)

	history := b.History()
	if len(history) != 3 {
		t.Fatalf("expected 3 history events, got %d", len(history))
	}
	if history[0].Message != "msg1" {
		t.Errorf("history[0].Message = %q, want %q", history[0].Message, "msg1")
	}
	if history[2].Type != EventHealthCheckFailed {
		t.Errorf("history[2].Type = %v, want %v", history[2].Type, EventHealthCheckFailed)
	}
}

func TestBusHistoryOverflow(t *testing.T) {
	b := NewWithHistory(3)

	for i := 0; i < 5; i++ {
		b.Emit(EventDeployStarted, "src", fmt.Sprintf("event-%d", i), SeverityInfo, nil)
	}

	history := b.History()
	if len(history) != 3 {
		t.Fatalf("expected 3 history events (cap), got %d", len(history))
	}
	if history[0].Message != "event-2" {
		t.Errorf("history[0].Message = %q, want %q (oldest kept)", history[0].Message, "event-2")
	}
	if history[2].Message != "event-4" {
		t.Errorf("history[2].Message = %q, want %q (newest)", history[2].Message, "event-4")
	}
}

func TestBusHistoryLast(t *testing.T) {
	b := New()

	for i := 0; i < 10; i++ {
		b.Emit(EventBuildStarted, "src", fmt.Sprintf("event-%d", i), SeverityInfo, nil)
	}

	last := b.HistoryLast(3)
	if len(last) != 3 {
		t.Fatalf("expected 3 events, got %d", len(last))
	}
	if last[0].Message != "event-7" {
		t.Errorf("last[0].Message = %q, want %q", last[0].Message, "event-7")
	}
	if last[2].Message != "event-9" {
		t.Errorf("last[2].Message = %q, want %q", last[2].Message, "event-9")
	}
}

func TestBusHistoryByType(t *testing.T) {
	b := New()

	b.Emit(EventDeployStarted, "src", "msg1", SeverityInfo, nil)
	b.Emit(EventHealthCheckFailed, "src", "msg2", SeverityWarn, nil)
	b.Emit(EventDeployCompleted, "src", "msg3", SeverityInfo, nil)

	deploys := b.HistoryByType(EventDeployStarted)
	if len(deploys) != 1 {
		t.Fatalf("expected 1 deploy event, got %d", len(deploys))
	}
	if deploys[0].Message != "msg1" {
		t.Errorf("deploys[0].Message = %q, want %q", deploys[0].Message, "msg1")
	}
}

func TestBusHistoryBySeverity(t *testing.T) {
	b := New()

	b.Emit(EventDeployStarted, "src", "msg1", SeverityInfo, nil)
	b.Emit(EventHealthCheckFailed, "src", "msg2", SeverityWarn, nil)
	b.Emit(EventDeployCompleted, "src", "msg3", SeverityInfo, nil)
	b.Emit(EventDeployFailed, "src", "msg4", SeverityError, nil)

	warns := b.HistoryBySeverity(SeverityWarn)
	if len(warns) != 1 {
		t.Fatalf("expected 1 warn event, got %d", len(warns))
	}

	errors := b.HistoryBySeverity(SeverityError)
	if len(errors) != 1 {
		t.Fatalf("expected 1 error event, got %d", len(errors))
	}
}

func TestBusHistoryCount(t *testing.T) {
	b := New()

	if b.HistoryCount() != 0 {
		t.Errorf("expected 0, got %d", b.HistoryCount())
	}

	b.Emit(EventDeployStarted, "src", "msg", SeverityInfo, nil)
	b.Emit(EventDeployCompleted, "src", "msg", SeverityInfo, nil)

	if b.HistoryCount() != 2 {
		t.Errorf("expected 2, got %d", b.HistoryCount())
	}
}
