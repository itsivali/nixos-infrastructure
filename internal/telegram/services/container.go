package services

// Container holds all shared services for dependency injection.
type Container struct {
	Runner     *Runner
	System     *SystemService
	Nix        *NixService
	Git        *GitService
	GitOps     *GitOpsService
	Desktop    *DesktopService
	Monitoring *MonitoringService
	Security   *SecurityService
	Tailscale  *TailscaleService
	Firewall   *FirewallService
	Platform   *PlatformService
	AI         *AIService
}

// NewContainer creates a Container with all services wired together.
func NewContainer(repoDir string) *Container {
	runner := NewRunner()

	system := NewSystemService(runner)
	nix := NewNixService(runner, repoDir)
	git := NewGitService(runner, repoDir)
	gitops := NewGitOpsService(runner, repoDir, nix, git)
	desktop := NewDesktopService(runner)
	monitoring := NewMonitoringService(runner)
	security := NewSecurityService(runner)
	tailscale := NewTailscaleService(runner)
	firewall := NewFirewallService(runner)
	platform := NewPlatformService(runner, repoDir)
	ai := NewAIService(runner, repoDir)

	return &Container{
		Runner:     runner,
		System:     system,
		Nix:        nix,
		Git:        git,
		GitOps:     gitops,
		Desktop:    desktop,
		Monitoring: monitoring,
		Security:   security,
		Tailscale:  tailscale,
		Firewall:   firewall,
		Platform:   platform,
		AI:         ai,
	}
}
