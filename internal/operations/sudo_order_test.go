package operations

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Regression test for the gitops reconciler's sudo activation step.
//
// sudo utcomes are LAST-MATCH-WINS: when two rules match the same command
// for the same user, the rule that appears LATER in /etc/sudoers is used.
//
// laptop.nix used to emit (for `ivali`):
//
//	ivali ALL=(ALL:ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild
//	ivali ALL=(ALL:ALL) ALL                       <- shadows the NOPASSWD
//
// Because the broad `ALL` rule appeared AFTER the narrow NOPASSWD rule, every
// `sudo nixos-rebuild switch` (gitops-reconcile.sh, the reconciler's
// activation step) required a password and failed non-interactively under the
// systemd service. The same failure pattern also blocked `ci-deploy`.
//
// Fixed by emitting the catch-all FIRST and the NOPASSWD entries after it:
//
//	ivali ALL=(ALL:ALL) ALL
//	ivali ALL=(ALL:ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild
//
// This test asserts that ordering invariant for the operator user in the
// laptop host template. Fixed in the same commit as this test.

func readLaptopTemplate(t *testing.T) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "..", "lib", "host-templates", "laptop.nix"))
	if err != nil {
		t.Fatalf("read laptop.nix: %v", err)
	}
	return string(data)
}

// The broad `ALL` catch-all for the operator user must be emitted BEFORE the
// NOPASSWD rules, otherwise sudo's last-match-wins cancels passwordless
// nixos-rebuild and the GitOps reconciler can never activate a deployment.
func TestSudoNopasswdRulesAfterCatchAll(t *testing.T) {
	tmpl := readLaptopTemplate(t)
	lines := strings.Split(tmpl, "\n")

	// Find the emitted rule blocks for the operator user.
	var allIdx, nopasswdIdx int = -1, -1
	var allRule, nopasswdRule string
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "users = [ userName ];") {
			continue
		}
		if strings.Contains(trimmed, `{ command = "ALL"; }`) {
			allIdx = i
			allRule = trimmed
		}
		if strings.Contains(trimmed, `command = "/run/current-system/sw/bin/nixos-rebuild"`) {
			nopasswdIdx = i
			nopasswdRule = trimmed
		}
	}

	if allIdx == -1 {
		t.Fatalf("laptop.nix must contain an operator catch-all: rule { command = \"ALL\"; }")
	}
	if nopasswdIdx == -1 {
		t.Fatalf("laptop.nix must contain the NOPASSWD nixos-rebuild rule")
	}

	// Confirm the NOPASSWD block also carries the operator user (not just a
	// stray gitlab-runner entry) and the NOPASSWD option.
	block := strings.Join(lines[nopasswdIdx:][:1], " ")
	if !strings.Contains(block, "NOPASSWD") {
		// Scan a few lines up to confirm we are inside the ivali NOPASSWD block.
		window := strings.Join(lines[max(0, nopasswdIdx-4):nopasswdIdx+2], "\n")
		if !strings.Contains(window, "commands = [") || !strings.Contains(window, "NOPASSWD") {
			t.Fatalf("NOPASSWD nixos-rebuild rule not inside a NOPASSWD block:\n%s", window)
		}
	}

	if nopasswdIdx < allIdx {
		t.Errorf(
			"sudo NOPASSWD rule (line %d) appears BEFORE the catch-all ALL (line %d): sudo is last-match-wins, so the catch-all shadows NOPASSWD and the GitOps reconciler's `sudo nixos-rebuild switch` would prompt for a password and fail.\nRules:\n  ALL      = %s\n  NOPASSWD = %s",
			nopasswdIdx+1, allIdx+1, allRule, nopasswdRule,
		)
	}
}

func TestSudoNopasswdBlockUsesOperatorUser(t *testing.T) {
	tmpl := readLaptopTemplate(t)
	// The NOPASSWD rule for nixos-rebuild must reference the operator's
	// userName, not a hardcoded name or another user.
	idx := strings.Index(tmpl, `command = "/run/current-system/sw/bin/nixos-rebuild"`)
	if idx == -1 {
		t.Fatal("no nixos-rebuild NOPASSWD rule in laptop.nix")
	}
	before := tmpl[:idx]
	lastUsers := before[strings.LastIndex(before, "users = ["):]
	// The NOPASSWD block must be the operator block, i.e. the nearest
	// preceding users list uses `userName`.
	if !strings.Contains(lastUsers, "userName") {
		t.Errorf("NOPASSWD nixos-rebuild rule should belong to the operator (userName) block, nearest preceding users list: %q", lastUsers)
	}
}
