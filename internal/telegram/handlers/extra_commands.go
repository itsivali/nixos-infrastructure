package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/renderer"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

// AICommand shows AI system status.
type AICommand struct {
	api *telegram.API
	svc *services.Container
}

func NewAICommand(api *telegram.API, svc *services.Container) *AICommand {
	return &AICommand{api: api, svc: svc}
}

func (c *AICommand) Name() string                      { return "ai" }
func (c *AICommand) Description() string               { return "Show AI system status" }
func (c *AICommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *AICommand) Execute(ctx context.Context, msg *telegram.Message) error {
	status := c.svc.AI.Status()

	var lines []string
	lines = append(lines, "*🤖 AI Systems Status*")
	lines = append(lines, "")
	lines = append(lines, renderer.KeyValue("💻 OpenCode", status.OpenCode))
	lines = append(lines, renderer.KeyValue("🦾 OpenHands", status.OpenHands))
	lines = append(lines, renderer.KeyValue("📚 Knowledge base", status.KnowledgeBase))
	lines = append(lines, "")
	lines = append(lines, "_All tasks route to OpenCode_")

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

// OpenCodeCommand checks OpenCode configuration.
type OpenCodeCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewOpenCodeCommand(api *telegram.API, svc *services.Container) *OpenCodeCommand {
	return &OpenCodeCommand{api: api, svc: svc}
}

func (c *OpenCodeCommand) Name() string                      { return "opencode" }
func (c *OpenCodeCommand) Description() string               { return "Check OpenCode status" }
func (c *OpenCodeCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *OpenCodeCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	status := c.svc.AI.Status()

	var lines []string
	lines = append(lines, "*💻 OpenCode Status*")
	lines = append(lines, "")
	lines = append(lines, renderer.KeyValue("Configuration", status.OpenCode))
	lines = append(lines, renderer.KeyValue("Knowledge base", status.KnowledgeBase))
	lines = append(lines, "")
	lines = append(lines, "_OpenCode is your interactive CLI AI assistant._")
	lines = append(lines, "_Use it for debugging, builds, tests, and editing._")

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

// NetworkCommand shows network status.
type NetworkCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewNetworkCommand(api *telegram.API, svc *services.Container) *NetworkCommand {
	return &NetworkCommand{api: api, svc: svc}
}

func (c *NetworkCommand) Name() string                      { return "network" }
func (c *NetworkCommand) Description() string               { return "Show network status" }
func (c *NetworkCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *NetworkCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	info := c.svc.Platform.NetworkStatus()

	var lines []string
	lines = append(lines, "*🌐 Network Status*")
	lines = append(lines, "")
	lines = append(lines, renderer.KeyValue("Hostname", info.Hostname))
	lines = append(lines, renderer.KeyValue("IP", info.DefaultIP))
	lines = append(lines, renderer.KeyValue("Gateway", info.Gateway))
	if info.Interfaces != "" {
		lines = append(lines, "")
		lines = append(lines, "*Interfaces:*")
		for _, iface := range strings.Split(info.Interfaces, "\n") {
			iface = strings.TrimSpace(iface)
			if iface != "" {
				lines = append(lines, fmt.Sprintf("  • `%s`", iface))
			}
		}
	}
	if info.DNS != "" {
		lines = append(lines, "")
		lines = append(lines, "*DNS:*")
		lines = append(lines, renderer.CodeBlock(info.DNS))
	}

	return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
}

// JournalCommand shows system journal errors or a specific service's logs.
type JournalCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewJournalCommand(api *telegram.API, svc *services.Container) *JournalCommand {
	return &JournalCommand{api: api, svc: svc}
}

func (c *JournalCommand) Name() string                      { return "journal" }
func (c *JournalCommand) Description() string               { return "Show system journal" }
func (c *JournalCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *JournalCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	var output string
	if args != "" {
		output = c.svc.Platform.JournalService(args)
	} else {
		output = c.svc.Platform.JournalErrors()
	}
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

// RepoCommand shows repository status.
type RepoCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewRepoCommand(api *telegram.API, svc *services.Container) *RepoCommand {
	return &RepoCommand{api: api, svc: svc}
}

func (c *RepoCommand) Name() string                      { return "repo" }
func (c *RepoCommand) Description() string               { return "Show repository status" }
func (c *RepoCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *RepoCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Platform.Status()
	return c.api.SendLongMessage(msg.ChatID, "*📁 Repository Status*\n\n"+renderer.CodeBlock(output), 3500)
}

// SearchCommand searches the repository.
type SearchCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewSearchCommand(api *telegram.API, svc *services.Container) *SearchCommand {
	return &SearchCommand{api: api, svc: svc}
}

func (c *SearchCommand) Name() string                      { return "search" }
func (c *SearchCommand) Description() string               { return "Search repository modules" }
func (c *SearchCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *SearchCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	query := strings.TrimSpace(msg.Args)
	if query == "" {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/search <query>`")
	}
	output := c.svc.Platform.Search(query)
	return c.api.SendLongMessage(msg.ChatID, "*🔍 Search Results*\n\n"+renderer.CodeBlock(output), 3500)
}

// GraphCommand shows the module import tree.
type GraphCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewGraphCommand(api *telegram.API, svc *services.Container) *GraphCommand {
	return &GraphCommand{api: api, svc: svc}
}

func (c *GraphCommand) Name() string                      { return "graph" }
func (c *GraphCommand) Description() string               { return "Show module import graph" }
func (c *GraphCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *GraphCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Platform.GraphTree()
	return c.api.SendLongMessage(msg.ChatID, "*📊 Module Graph*\n\n"+renderer.CodeBlock(output), 3500)
}

// SuggestCommand analyzes repository and recommends improvements.
type SuggestCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewSuggestCommand(api *telegram.API, svc *services.Container) *SuggestCommand {
	return &SuggestCommand{api: api, svc: svc}
}

func (c *SuggestCommand) Name() string                      { return "suggest" }
func (c *SuggestCommand) Description() string               { return "Repository improvement suggestions" }
func (c *SuggestCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *SuggestCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Platform.Suggest()
	return c.api.SendLongMessage(msg.ChatID, "*💡 Suggestions*\n\n"+renderer.CodeBlock(output), 3500)
}
