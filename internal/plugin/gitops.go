package plugin

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

const GitOpsPluginName = "gitops"

type GitOpsPlugin struct {
	BasePlugin
	repoPath string
}

func NewGitOpsPlugin(repoPath string) *GitOpsPlugin {
	return &GitOpsPlugin{
		BasePlugin: NewBase("GitOps Reconciliation"),
		repoPath:   repoPath,
	}
}

func (p *GitOpsPlugin) Name() string { return GitOpsPluginName }

func (p *GitOpsPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	engine.SetDetail(p.Name(),
		state.WithVersion("1.0.0"),
		state.WithDependencies([]string{"security"}),
		state.WithMeta("repo", p.repoPath),
	)
	return nil
}

func (p *GitOpsPlugin) Status() *state.ComponentStatus {
	meta := make(map[string]string)

	if p.repoPath != "" {
		meta["repo"] = p.repoPath
	}

	branch := "unknown"
	if out, err := exec.Command("git", "-C", p.repoPath, "rev-parse", "--abbrev-ref", "HEAD").Output(); err == nil {
		branch = strings.TrimSpace(string(out))
	}
	meta["branch"] = branch

	gitClean := true
	if out, err := exec.Command("git", "-C", p.repoPath, "status", "--porcelain").Output(); err == nil && len(out) > 0 {
		gitClean = false
	}

	reconcilerActive := false
	if out, err := exec.Command("systemctl", "is-active", "gitops-reconciler.timer").Output(); err == nil {
		reconcilerActive = strings.TrimSpace(string(out)) == "active"
	}

	stateVal := state.StateHealthy
	var messages []string

	if !gitClean {
		messages = append(messages, "dirty worktree")
		stateVal = state.StateWarning
	}
	if !reconcilerActive {
		messages = append(messages, "reconciler timer not active")
		stateVal = state.StateWarning
	}
	if branch != "main" && branch != "master" {
		messages = append(messages, fmt.Sprintf("on branch: %s", branch))
	}

	message := "healthy"
	if len(messages) > 0 {
		message = strings.Join(messages, "; ")
	}

	return &state.ComponentStatus{
		Name:     p.Name(),
		State:    stateVal,
		Message:  message,
		Metadata: meta,
	}
}

func (p *GitOpsPlugin) Shutdown() error { return nil }

func GitOpsPluginFromEnv() *GitOpsPlugin {
	repo := os.Getenv("REPO_DIR")
	if repo == "" {
		repo = "/home/ivali/nixos-infrastructure"
	}
	return NewGitOpsPlugin(repo)
}
