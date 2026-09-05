package commands

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

// runtimeHealthChecks returns warn-only runtime probes for the machine the
// doctor runs on. They are intentionally never StatusFail: doctor is used as
// the post-rollback and pre-deploy health gate (rollback.sh, gitops-reconcile.sh),
// and a headless/test host legitimately lacks an audio stack, Wayland session, or
// Firefox profile. Missing probes surface as warnings, not gate failures.
func runtimeHealthChecks() []terminal.CheckItem {
	var items []terminal.CheckItem

	items = append(items, checkUserService("pipewire", "audio"),
		checkUserService("wireplumber", "audio-routing"))

	items = append(items, checkWayland())

	items = append(items, checkFirefoxProfile())

	items = append(items, checkSOPSKey(), checkSecretsMounted())

	items = append(items, checkBackupTimer())

	return items
}

// checkUserService reports a systemd user service; degraded/warn when the user
// session is unreachable (headless) rather than failing.
func checkUserService(unit, label string) terminal.CheckItem {
	svc := unit + ".service"
	out, err := exec.Command("systemctl", "--user", "is-active", svc).CombinedOutput()
	status := strings.TrimSpace(string(out))
	switch {
	case err == nil && status == "active":
		return terminal.CheckItem{Label: fmt.Sprintf("%s (%s)", unit, label), Status: terminal.StatusPass, Detail: "active"}
	case err == nil:
		return terminal.CheckItem{Label: fmt.Sprintf("%s (%s)", unit, label), Status: terminal.StatusWarn, Detail: status}
	default:
		return terminal.CheckItem{Label: fmt.Sprintf("%s (%s)", unit, label), Status: terminal.StatusWarn, Detail: "no user session (headless?)"}
	}
}

func checkWayland() terminal.CheckItem {
	if os.Getenv("XDG_SESSION_TYPE") == "wayland" {
		return terminal.CheckItem{Label: "Wayland session", Status: terminal.StatusPass, Detail: "XDG_SESSION_TYPE=wayland"}
	}
	return terminal.CheckItem{Label: "Wayland session", Status: terminal.StatusWarn, Detail: os.Getenv("XDG_SESSION_TYPE") + " (no Wayland session)"}
}

func checkFirefoxProfile() terminal.CheckItem {
	home, err := os.UserHomeDir()
	if err != nil {
		return terminal.CheckItem{Label: "Firefox profile", Status: terminal.StatusWarn, Detail: "cannot determine home"}
	}
	profiles := filepath.Join(home, ".mozilla", "firefox", "profiles.ini")
	if _, err := os.Stat(profiles); err == nil {
		return terminal.CheckItem{Label: "Firefox profile", Status: terminal.StatusPass, Detail: profiles}
	}
	return terminal.CheckItem{Label: "Firefox profile", Status: terminal.StatusWarn, Detail: "no profile (Firefox never run)"}
}

func checkSOPSKey() terminal.CheckItem {
	home, err := os.UserHomeDir()
	if err != nil {
		return terminal.CheckItem{Label: "SOPS age key", Status: terminal.StatusWarn, Detail: "cannot determine home"}
	}
	key := filepath.Join(home, ".config", "sops", "age", "keys.txt")
	if _, err := os.Stat(key); err == nil {
		return terminal.CheckItem{Label: "SOPS age key", Status: terminal.StatusPass, Detail: key}
	}
	return terminal.CheckItem{Label: "SOPS age key", Status: terminal.StatusWarn, Detail: "not found — secrets cannot decrypt"}
}

func checkSecretsMounted() terminal.CheckItem {
	// /run/secrets is a symlink to /run/secrets.d/<N> owned by root. A
	// non-root operator may not be able to read the directory even when
	// secrets ARE mounted, so presence is the signal — not readability.
	if _, err := os.Stat("/run/secrets"); err != nil {
		return terminal.CheckItem{Label: "/run/secrets", Status: terminal.StatusWarn, Detail: "not mounted on this host"}
	}
	names := []string{}
	if entries, err := os.ReadDir("/run/secrets"); err == nil {
		for _, e := range entries {
			names = append(names, e.Name())
		}
		if len(names) == 0 {
			return terminal.CheckItem{Label: "/run/secrets", Status: terminal.StatusWarn, Detail: "mounted but empty"}
		}
		return terminal.CheckItem{Label: "/run/secrets", Status: terminal.StatusPass, Detail: strings.Join(names, ", ")}
	}
	// Directory exists but is not readable by the current user (root-owned).
	return terminal.CheckItem{Label: "/run/secrets", Status: terminal.StatusPass, Detail: "mounted (root-only access)"}
}

func checkBackupTimer() terminal.CheckItem {
	// fleet.backup is optional per-host. Following the platform convention
	// (CheckTailscale: "not installed" → healthy), a host without the backup
	// feature is healthy by declaration — only an enabled-but-failed timer is
	// a warning.
	if _, err := exec.Command("systemctl", "list-unit-files", "restic-backup.timer").Output(); err != nil {
		return terminal.CheckItem{Label: "restic-backup timer", Status: terminal.StatusPass, Detail: "not enabled on this host"}
	}
	out, err := exec.Command("systemctl", "is-active", "restic-backup.timer").CombinedOutput()
	status := strings.TrimSpace(string(out))
	if err == nil && status == "active" {
		return terminal.CheckItem{Label: "restic-backup timer", Status: terminal.StatusPass, Detail: "active"}
	}
	return terminal.CheckItem{Label: "restic-backup timer", Status: terminal.StatusWarn, Detail: "enabled but " + status}
}