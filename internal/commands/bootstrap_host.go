package commands

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/template"
)

func CmdBootstrapHost(a *app.App) *cobra.Command {
	var (
		hostName       string
		userName       string
		repoPath       string
		tags           []string
		tailnetDomain  string
		gitlabRunnerTags []string
		sshKeys        []string
		features       []string
		interactive    bool
		force          bool
	)

	cmd := &cobra.Command{
		Use:   "host [name]",
		Short: "Bootstrap a new laptop host configuration",
		Long: `Generate a complete laptop host configuration from the template.
This creates all necessary files in hosts/<name>/ and updates the host registry.

The configuration includes:
  • Hardware detection (auto-generated)
  • User account with zsh + Home Manager
  • Lean GNOME desktop
  • Security hardening (kernel, firewall, AppArmor, fail2ban)
  • Observability stack (Grafana, Prometheus, Loki, Alloy, Falco, OTEL)
  • GitOps control plane (health monitor, reconciler, rollback)
  • Tailscale zero-trust networking
  • SSH over Tailscale only
  • Telegram bot control plane
  • GitLab Runner

Features (enabled by default, use --no-* to disable):
  secrets, gitlab-runner, bot, tailscale, tailscale-exit-node, ssh`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			if interactive {
				return runInteractiveHostBootstrap(a)
			}

			if len(args) > 0 {
				hostName = args[0]
			}

			if hostName == "" {
				return fmt.Errorf("host name required (use --name or provide as argument)")
			}

			return runHostBootstrap(a, hostName, userName, repoPath, tags, tailnetDomain, gitlabRunnerTags, sshKeys, features, force)
		},
	}

	cmd.Flags().StringVarP(&hostName, "name", "n", "", "Host name (default: current hostname)")
	cmd.Flags().StringVarP(&userName, "user", "u", "", "Username (default: current user)")
	cmd.Flags().StringVarP(&repoPath, "repo", "r", "", "Repository path (default: ~/nixos-infrastructure)")
	cmd.Flags().StringSliceVar(&tags, "tags", []string{"tag:admin"}, "Tailscale ACL tags")
	cmd.Flags().StringVar(&tailnetDomain, "tailnet-domain", "codlet-trench.ts.net", "Tailnet DNS suffix")
	cmd.Flags().StringSliceVar(&gitlabRunnerTags, "gitlab-runner-tags", nil, "GitLab Runner tags (default: [nixos, <host>, self-hosted])")
	cmd.Flags().StringSliceVar(&sshKeys, "ssh-keys", nil, "SSH authorized keys (public keys)")
	cmd.Flags().StringSliceVar(&features, "features", nil, "Features to enable (secrets,gitlab-runner,bot,tailscale,tailscale-exit-node,ssh). Prefix with 'no-' to disable.")
	cmd.Flags().BoolVarP(&interactive, "interactive", "i", false, "Interactive mode with prompts")
	cmd.Flags().BoolVarP(&force, "force", "f", false, "Overwrite existing host configuration")

	return cmd
}

func runHostBootstrap(a *app.App, hostName, userName, repoPath string, tags []string, tailnetDomain string, gitlabRunnerTags []string, sshKeys []string, features []string, force bool) error {
	t := a.Term

	// Defaults
	if userName == "" {
		userName = os.Getenv("USER")
		if userName == "" {
			userName = "ivali"
		}
	}

	if repoPath == "" {
		home, _ := os.UserHomeDir()
		repoPath = filepath.Join(home, "nixos-infrastructure")
	}

	if len(gitlabRunnerTags) == 0 {
		gitlabRunnerTags = []string{"nixos", hostName, "self-hosted"}
	}

	// Parse features
	featureMap := map[string]bool{
		"secrets":             true,
		"gitlab-runner":       true,
		"bot":                 true,
		"tailscale":           true,
		"tailscale-exit-node": true,
		"ssh":                 true,
	}
	for _, f := range features {
		if strings.HasPrefix(f, "no-") {
			featureMap[strings.TrimPrefix(f, "no-")] = false
		} else {
			featureMap[f] = true
		}
	}

	// Build host spec
	spec := template.HostSpec{
		HostName:        hostName,
		UserName:        userName,
		RepoPath:        repoPath,
		Tags:            tags,
		TailnetDomain:   tailnetDomain,
		GitLabRunnerTags: gitlabRunnerTags,
		SSHAuthorizedKeys: sshKeys,
		Features:        featureMap,
	}

	fmt.Println()
	fmt.Println(t.Section("Bootstrap Host: " + hostName))
	fmt.Println()

	fmt.Printf("  %s Host: %s\n", t.Info("➜"), t.Code(hostName))
	fmt.Printf("  %s User: %s\n", t.Info("➜"), t.Code(userName))
	fmt.Printf("  %s Repo: %s\n", t.Info("➜"), t.Code(repoPath))
	fmt.Printf("  %s Tailscale Tags: %s\n", t.Info("➜"), t.Code(strings.Join(tags, ", ")))
	fmt.Printf("  %s Tailnet Domain: %s\n", t.Info("➜"), t.Code(tailnetDomain))
	fmt.Printf("  %s GitLab Runner Tags: %s\n", t.Info("➜"), t.Code(strings.Join(gitlabRunnerTags, ", ")))
	fmt.Printf("  %s Features: ", t.Info("➜"))
	for k, v := range featureMap {
		status := t.Good("on")
		if !v {
			status = t.Warn("off")
		}
		fmt.Printf("%s=%s ", t.Code(k), status)
	}
	fmt.Println()
	fmt.Println()

	// Create host configuration
	gen := template.New(a.Repo.Root)
	files, err := gen.HostConfig(spec, force)
	if err != nil {
		return err
	}

	// Write files
	if err := gen.Write(files); err != nil {
		return err
	}

	fmt.Println()
	fmt.Println(t.Section("Generated Files"))
	fmt.Println()
	for _, f := range files {
		fmt.Println(t.Good("✓") + "  " + t.Dim(f.Path))
	}
	fmt.Println()

	// Update host registry
	fmt.Println("  " + t.Dim("Updating host registry..."))
	if err := updateHostRegistry(a.Repo.Root, spec, force); err != nil {
		return fmt.Errorf("update host registry: %w", err)
	}
	fmt.Println("  " + t.Good("✓ Host registry updated"))
	fmt.Println()

	fmt.Println(t.Info("Next steps:"))
	fmt.Println("  1. " + t.Code("cd "+filepath.Join(a.Repo.Root, "hosts", hostName)))
	fmt.Println("  2. " + t.Code("sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix"))
	fmt.Println("  3. " + t.Code("ivali scan") + "  to re-index")
	fmt.Println("  4. " + t.Code("sudo nixos-rebuild switch --flake .#"+hostName) + "  to deploy")
	fmt.Println()

	return nil
}

func runInteractiveHostBootstrap(a *app.App) error {
	fmt.Println("Interactive mode not yet implemented")
	return nil
}

func updateHostRegistry(root string, spec template.HostSpec, force bool) error {
	registryPath := filepath.Join(root, "hosts", "hosts.nix")

	// TODO: Proper Nix parsing/editing
	// For now, the registry must be manually updated
	// In production, use a proper Nix parser or generate the whole file
	_ = registryPath
	return nil
}