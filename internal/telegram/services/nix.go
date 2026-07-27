package services

import (
	"fmt"
	"strings"
)

// NixService provides NixOS and Nix package manager operations.
type NixService struct {
	runner  *Runner
	repoDir string
}

// NewNixService creates a new NixService.
func NewNixService(runner *Runner, repoDir string) *NixService {
	return &NixService{runner: runner, repoDir: repoDir}
}

// Generations returns the list of NixOS generations.
func (s *NixService) Generations() string {
	return s.runner.Run("sudo nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -10", 30)
}

// GenerationCount returns the number of NixOS generations.
func (s *NixService) GenerationCount() string {
	return strings.TrimSpace(s.runner.Run(
		"nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | wc -l", 10))
}

// CurrentGeneration returns the current NixOS generation identifier.
func (s *NixService) CurrentGeneration() string {
	return strings.TrimSpace(s.runner.Run(
		"readlink /run/current-system 2>/dev/null | grep -oP 'nixos-\\d+' || echo unknown", 5))
}

// StoreSize returns Nix store size information.
func (s *NixService) StoreSize() (roots, disk string) {
	roots = s.runner.Run("nix-store -q --size-roots /nix/store 2>/dev/null || echo 'nix-store not available'", 30)
	disk = s.runner.Run("du -sh /nix/store 2>/dev/null || echo 'unknown'", 30)
	return
}

// SystemPackageCount returns the number of installed system packages.
func (s *NixService) SystemPackageCount() string {
	return strings.TrimSpace(s.runner.Run(
		"nix-store -q --requisites /run/current-system 2>/dev/null | wc -l", 30))
}

// Rebuild runs nixos-rebuild switch for the given host.
func (s *NixService) Rebuild(host string) string {
	return s.runner.Run(
		fmt.Sprintf("sudo nixos-rebuild switch --flake %s#%s 2>&1", s.repoDir, host), 600)
}

// RebuildWithRollback runs nixos-rebuild switch --rollback.
func (s *NixService) RebuildWithRollback() string {
	return s.runner.Run("sudo nixos-rebuild switch --rollback 2>&1", 300)
}

// GarbageCollect runs Nix garbage collection.
func (s *NixService) GarbageCollect() string {
	return s.runner.Run("sudo nix-collect-garbage -d 2>&1", 300)
}

// FlakeCheck runs nix flake check.
func (s *NixService) FlakeCheck() string {
	output := s.runner.Run(
		fmt.Sprintf("cd %s && nix flake check --no-build 2>&1 | head -20", s.repoDir), 60)
	return strings.TrimSpace(output)
}

// FlakeUpdate pulls latest changes and updates flake inputs.
func (s *NixService) FlakeUpdate() string {
	return s.runner.Run(
		fmt.Sprintf("cd %s && git pull && nix flake update 2>&1", s.repoDir), 120)
}

// NixCommand executes a raw nix command with arguments (no shell injection).
func (s *NixService) NixCommand(args ...string) string {
	fullArgs := append([]string{"nix"}, args...)
	return s.runner.RunArgs(120, fullArgs...)
}

// PkgInfo queries installed packages.
func (s *NixService) PkgInfo(query string) string {
	if query == "" {
		return s.runner.Run("nix-env -q 2>/dev/null | wc -l", 10)
	}
	args := append([]string{"nix-env", "-q"}, strings.Fields(query)...)
	return s.runner.RunArgs(30, args...)
}
