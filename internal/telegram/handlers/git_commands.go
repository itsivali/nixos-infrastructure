package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// Git commands — VCS and forges.

type GitCommand struct {
	api *telegram.API
}

func NewGitCommand(config *telegram.Config) *GitCommand {
	return &GitCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *GitCommand) Name() string                      { return "git" }
func (c *GitCommand) Description() string               { return "Git operations" }
func (c *GitCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *GitCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		output := runCmdAsUser("cd /home/ivali/nixos-infrastructure && git status --short 2>/dev/null", 10)
		return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
	}
	output := runCmdAsUser(fmt.Sprintf("cd /home/ivali/nixos-infrastructure && git %s 2>&1", args), 30)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type GithubCommand struct {
	api *telegram.API
}

func NewGithubCommand(config *telegram.Config) *GithubCommand {
	return &GithubCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *GithubCommand) Name() string                      { return "github" }
func (c *GithubCommand) Description() string               { return "GitHub operations" }
func (c *GithubCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *GithubCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("gh repo view 2>/dev/null || echo 'gh not available'", 10)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type GitlabCommand struct {
	api *telegram.API
}

func NewGitlabCommand(config *telegram.Config) *GitlabCommand {
	return &GitlabCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *GitlabCommand) Name() string                      { return "gitlab" }
func (c *GitlabCommand) Description() string               { return "GitLab operations" }
func (c *GitlabCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *GitlabCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmd("glab mr list 2>/dev/null || echo 'glab not available'", 10)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}
