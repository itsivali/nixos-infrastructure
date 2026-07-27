package handlers

import (
	"context"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/renderer"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type GitCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewGitCommand(api *telegram.API, svc *services.Container) *GitCommand {
	return &GitCommand{api: api, svc: svc}
}

func (c *GitCommand) Name() string                      { return "git" }
func (c *GitCommand) Description() string               { return "Git operations" }
func (c *GitCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *GitCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		output := c.svc.Git.Status()
		return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
	}
	fields := strings.Fields(args)
	output := c.svc.Git.Execute(fields[0], fields[1:]...)
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type GithubCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewGithubCommand(api *telegram.API, svc *services.Container) *GithubCommand {
	return &GithubCommand{api: api, svc: svc}
}

func (c *GithubCommand) Name() string                      { return "github" }
func (c *GithubCommand) Description() string               { return "GitHub operations" }
func (c *GithubCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *GithubCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Git.GitHubView()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type GitlabCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewGitlabCommand(api *telegram.API, svc *services.Container) *GitlabCommand {
	return &GitlabCommand{api: api, svc: svc}
}

func (c *GitlabCommand) Name() string                      { return "gitlab" }
func (c *GitlabCommand) Description() string               { return "GitLab operations" }
func (c *GitlabCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *GitlabCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Git.GitLabMRs()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}
