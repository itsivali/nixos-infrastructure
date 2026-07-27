package services

import (
	"fmt"
	"strings"
)

// GitService provides Git VCS operations.
type GitService struct {
	runner  *Runner
	repoDir string
}

// NewGitService creates a new GitService.
func NewGitService(runner *Runner, repoDir string) *GitService {
	return &GitService{runner: runner, repoDir: repoDir}
}

// Status returns git status (short format).
func (s *GitService) Status() string {
	return s.runner.RunAsUser(
		fmt.Sprintf("cd %s && git status --short 2>/dev/null", s.repoDir), 10)
}

// Log returns recent git log.
func (s *GitService) Log(args ...string) string {
	fullArgs := append([]string{"-C", s.repoDir, "git", "log"}, args...)
	return s.runner.RunArgs(30, fullArgs...)
}

// Execute runs a whitelisted git subcommand.
func (s *GitService) Execute(subcmd string, args ...string) string {
	allowed := map[string]bool{
		"status": true, "log": true, "diff": true, "show": true,
		"branch": true, "remote": true, "tag": true, "stash": true,
		"blame": true, "shortlog": true, "describe": true,
	}
	if !allowed[subcmd] {
		return "Git subcommand not allowed. Use: status, log, diff, show, branch, remote, tag, stash, blame, shortlog, describe"
	}
	fullArgs := append([]string{"-C", s.repoDir, "git", subcmd}, args...)
	return s.runner.RunArgs(30, fullArgs...)
}

// HeadCommit returns the latest commit.
func (s *GitService) HeadCommit() string {
	return s.runner.Run(fmt.Sprintf("cd %s && git log --oneline -1 2>/dev/null", s.repoDir), 5)
}

// HeadCommitRelative returns the latest commit with relative time.
func (s *GitService) HeadCommitRelative() string {
	return s.runner.Run(fmt.Sprintf("cd %s && git log --oneline -1 --format='%%cr %%s' 2>/dev/null", s.repoDir), 5)
}

// DirtyCount returns the number of uncommitted changed files.
func (s *GitService) DirtyCount() string {
	return strings.TrimSpace(s.runner.Run(
		fmt.Sprintf("cd %s && git status --porcelain 2>/dev/null | wc -l", s.repoDir), 5))
}

// PullRemote pulls from origin.
func (s *GitService) PullRemote() string {
	return s.runner.Run(fmt.Sprintf("cd %s && git pull 2>&1", s.repoDir), 60)
}

// GitHubView shows GitHub repo info.
func (s *GitService) GitHubView() string {
	return s.runner.Run("gh repo view 2>/dev/null || echo 'gh not available'", 10)
}

// GitLabMRs lists GitLab merge requests.
func (s *GitService) GitLabMRs() string {
	return s.runner.Run("glab mr list 2>/dev/null || echo 'glab not available'", 10)
}
