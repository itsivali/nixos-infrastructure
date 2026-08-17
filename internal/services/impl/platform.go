package impl

import (
	"context"
	"fmt"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/services"
)

// NixOSPlatform implements services.PlatformService by invoking nixos-rebuild,
// nix, and git directly. It replaces the pattern of shelling out to `ivali`
// CLI commands from handlers.
type NixOSPlatform struct {
	repoDir string
}

// NewNixOSPlatform creates a platform service rooted at the given repository directory.
func NewNixOSPlatform(repoDir string) *NixOSPlatform {
	return &NixOSPlatform{repoDir: repoDir}
}

func (p *NixOSPlatform) Health(ctx context.Context) (*services.PlatformHealth, error) {
	ph := &services.PlatformHealth{Healthy: true}

	// Check core components
	checks := []struct {
		name string
		cmd  string
		args []string
	}{
		{"nix", "nix", []string{"--version"}},
		{"git", "git", []string{"--version"}},
		{"go", "go", []string{"version"}},
		{"sops", "sops", []string{"--version"}},
	}

	for _, c := range checks {
		ph.Plugins = append(ph.Plugins, services.PluginHealth{
			Name:    c.name,
			State:   "ok",
			Message: "available",
		})
		if _, err := exec.CommandContext(ctx, c.cmd, c.args...).Output(); err != nil {
			ph.Plugins[len(ph.Plugins)-1].State = "error"
			ph.Plugins[len(ph.Plugins)-1].Message = err.Error()
			ph.Healthy = false
		}
	}

	if ph.Healthy {
		ph.Message = "all platform components available"
	} else {
		ph.Message = "some components missing"
	}
	return ph, nil
}

func (p *NixOSPlatform) Status(ctx context.Context) (*services.PlatformStatus, error) {
	ps := &services.PlatformStatus{RepoRoot: p.repoDir}

	// Current generation
	if out, err := exec.CommandContext(ctx, "nixos-rebuild", "list-generations", "--no-out-link").CombinedOutput(); err == nil {
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		for _, line := range lines {
			if strings.Contains(line, "*") {
				fields := strings.Fields(line)
				if len(fields) > 0 {
					ps.CurrentGen, _ = strconv.Atoi(fields[0])
				}
				break
			}
		}
	}

	// Git branch
	if out, err := exec.CommandContext(ctx, "git", "-C", p.repoDir, "branch", "--show-current").Output(); err == nil {
		ps.Branch = strings.TrimSpace(string(out))
	}

	// Last commit
	if out, err := exec.CommandContext(ctx, "git", "-C", p.repoDir, "log", "-1", "--format=%h").Output(); err == nil {
		ps.LastCommit = strings.TrimSpace(string(out))
	}

	// Modified files
	if out, err := exec.CommandContext(ctx, "git", "-C", p.repoDir, "status", "--porcelain").Output(); err == nil {
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		if strings.TrimSpace(string(out)) == "" {
			ps.ModifiedFiles = 0
		} else {
			ps.ModifiedFiles = len(lines)
		}
	}

	return ps, nil
}

func (p *NixOSPlatform) Doctor(ctx context.Context) (*services.DiagnosticReport, error) {
	report := &services.DiagnosticReport{}

	addCheck := func(name string, cmd string, args ...string) {
		check := services.DiagnosticCheck{Name: name}
		if out, err := exec.CommandContext(ctx, cmd, args...).CombinedOutput(); err != nil {
			check.Passed = false
			check.Message = fmt.Sprintf("%v: %s", err, string(out))
			report.Failed++
		} else {
			check.Passed = true
			check.Message = strings.TrimSpace(string(out))
			report.Passed++
		}
		report.Checks = append(report.Checks, check)
	}

	addCheck("nix_flake_check", "nix", "flake", "check", "--no-build",
		"--extra-experimental-features", "nix-command flakes",
		filepath.Join(p.repoDir, "flake.nix"))
	addCheck("nixos_eval", "nix", "eval", ".#nixosConfigurations.prague.config.system.build.toplevel.name",
		"--extra-experimental-features", "nix-command flakes",
		"--no-write-lock-file", "--offline", p.repoDir)
	addCheck("go_build", "go", "build", "./...")
	addCheck("go_test", "go", "test", "./...")
	addCheck("git_clean", "git", "-C", p.repoDir, "diff", "--quiet", "HEAD")

	return report, nil
}

func (p *NixOSPlatform) Rebuild(ctx context.Context, host string) (string, error) {
	cmd := exec.CommandContext(ctx, "nixos-rebuild", "switch",
		"--flake", fmt.Sprintf("%s#%s", p.repoDir, host),
		"--no-write-lock-file",
		"--extra-experimental-features", "nix-command flakes")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return string(out), fmt.Errorf("rebuild failed: %w", err)
	}
	return string(out), nil
}

func (p *NixOSPlatform) Rollback(ctx context.Context) (string, error) {
	cmd := exec.CommandContext(ctx, "nixos-rebuild", "switch", "--rollback")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return string(out), fmt.Errorf("rollback failed: %w", err)
	}
	return string(out), nil
}
