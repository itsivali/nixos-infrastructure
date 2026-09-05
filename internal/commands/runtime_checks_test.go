package commands

import (
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

// runtimeHealthChecks must never fail the doctor gate: on a headless or test
// host the audio/Wayland/Firefox probes legitimately degrade to warnings.
// This guarantees they can't accidentally turn the rollback/pre-deploy gate red.
func TestRuntimeHealthChecks_NeverFailUnknowns(t *testing.T) {
	t.Setenv("XDG_SESSION_TYPE", "")

	checks := runtimeHealthChecks()

	if len(checks) == 0 {
		t.Fatal("expected at least one runtime check")
	}
	for _, c := range checks {
		if c.Status == terminal.StatusFail {
			t.Errorf("runtime check %q must not fail (status %v)", c.Label, c.Status)
		}
	}

	// The list always contains the wayland probe which reflects the env above.
	foundWayland := false
	foundPipewire := false
	for _, c := range checks {
		if c.Label == "Wayland session" {
			foundWayland = true
			if c.Status != terminal.StatusWarn {
				t.Errorf("expected Wayland to warn with XDG_SESSION_TYPE unset, got %v", c.Status)
			}
		}
		if c.Label == "pipewire (audio)" {
			foundPipewire = true
		}
	}
	if !foundWayland {
		t.Error("expected a Wayland session check to be present")
	}
	if !foundPipewire {
		t.Error("expected a pipewire check to be present")
	}
}

// Restoring the wayland probe to pass when a real Wayland session exists.
func TestRuntimeHealthChecks_WaylandPasses(t *testing.T) {
	t.Setenv("XDG_SESSION_TYPE", "wayland")

	found := false
	for _, c := range runtimeHealthChecks() {
		if c.Label == "Wayland session" {
			found = true
			if c.Status != terminal.StatusPass {
				t.Errorf("expected Wayland to pass with XDG_SESSION_TYPE=wayland, got %v", c.Status)
			}
		}
	}
	if !found {
		t.Fatal("expected a Wayland session check")
	}
}