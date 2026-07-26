package monitor

import (
	"sync/atomic"
	"testing"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

func TestMonitorStartStop(t *testing.T) {
	st := state.New()
	bus := events.New()
	mon := New(st, bus, time.Second)

	mon.RegisterCheck("test", func() (*CheckResult, error) {
		return &CheckResult{
			Name:    "test",
			State:   state.StateHealthy,
			Message: "ok",
		}, nil
	})

	mon.Start()
	if !mon.running {
		t.Error("expected monitor to be running")
	}

	mon.Stop()
	if mon.running {
		t.Error("expected monitor to be stopped")
	}
}

func TestMonitorRunsChecks(t *testing.T) {
	st := state.New()
	bus := events.New()
	mon := New(st, bus, 50*time.Millisecond)

	var checkRun atomic.Bool
	mon.RegisterCheck("test", func() (*CheckResult, error) {
		checkRun.Store(true)
		return &CheckResult{
			Name:    "test",
			State:   state.StateHealthy,
			Message: "ok",
		}, nil
	})

	mon.Start()
	time.Sleep(100 * time.Millisecond)
	mon.Stop()

	if !checkRun.Load() {
		t.Error("expected check to be run")
	}

	comp, ok := st.Get("test")
	if !ok {
		t.Fatal("expected component to exist")
	}
	if comp.State != state.StateHealthy {
		t.Errorf("expected healthy state, got %v", comp.State)
	}
}

func TestCheckDisk(t *testing.T) {
	result, err := CheckDisk()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result == nil {
		t.Fatal("expected result")
	}
	if result.Name != "disk" {
		t.Errorf("expected disk, got %s", result.Name)
	}
}

func TestCheckMemory(t *testing.T) {
	result, err := CheckMemory()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result == nil {
		t.Fatal("expected result")
	}
	if result.Name != "memory" {
		t.Errorf("expected memory, got %s", result.Name)
	}
}

func TestCheckLoad(t *testing.T) {
	result, err := CheckLoad()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result == nil {
		t.Fatal("expected result")
	}
	if result.Name != "load" {
		t.Errorf("expected load, got %s", result.Name)
	}
}

func TestCheckService(t *testing.T) {
	check := CheckService("NetworkManager")
	result, err := check()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result == nil {
		t.Fatal("expected result")
	}
}
