package handlers

import (
	"context"
	"fmt"
	"regexp"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// FirewallCommand shows nftables firewall status and rules summary.
type FirewallCommand struct {
	api *telegram.API
}

func NewFirewallCommand(config *telegram.Config) *FirewallCommand {
	return &FirewallCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *FirewallCommand) Name() string                      { return "firewall" }
func (c *FirewallCommand) Description() string               { return "Show firewall status" }
func (c *FirewallCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *FirewallCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Firewall Status (nftables)*")
	lines = append(lines, "")

	// Check if nft is available.
	check := runCmd("nft --version 2>/dev/null || echo 'nft not available'", 5)
	check = strings.TrimSpace(check)
	if strings.Contains(check, "not available") {
		lines = append(lines, "_nftables is not installed or not accessible._")
		return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
	}
	lines = append(lines, fmt.Sprintf("*Version:* `%s`", check))

	// Count total rules.
	ruleCount := runCmd("nft list ruleset 2>/dev/null | grep -c '^\t' || echo 0", 10)
	ruleCount = strings.TrimSpace(ruleCount)
	lines = append(lines, fmt.Sprintf("*Total rule lines:* `%s`", ruleCount))

	// Count rulesets (tables).
	tableCount := runCmd("nft list tables 2>/dev/null | grep -c '^table' || echo 0", 10)
	tableCount = strings.TrimSpace(tableCount)
	lines = append(lines, fmt.Sprintf("*Tables:* `%s`", tableCount))

	// Check default policies (hooks).
	lines = append(lines, "")
	lines = append(lines, "*Default policies (hooks):*")
	policies := runCmd("nft list ruleset 2>/dev/null | grep -E 'type (ip|ip6) hook' | head -10", 10)
	policies = strings.TrimSpace(policies)
	if policies != "" {
		// Format each policy line for readability.
		hookRe := regexp.MustCompile(`type\s+\S+\s+hook\s+(\S+).*policy\s+(\S+)`)
		for _, row := range strings.Split(policies, "\n") {
			row = strings.TrimSpace(row)
			if row == "" {
				continue
			}
			matches := hookRe.FindStringSubmatch(row)
			if len(matches) >= 3 {
				lines = append(lines, fmt.Sprintf("  `%s` \u2192 `%s`", matches[1], matches[2]))
			} else {
				lines = append(lines, fmt.Sprintf("  `%s`", row))
			}
		}
	} else {
		lines = append(lines, "  _No hook policies found._")
	}

	// First 50 lines of ruleset.
	lines = append(lines, "")
	lines = append(lines, "*Ruleset (first 50 lines):*")
	raw := runCmd("nft list ruleset 2>/dev/null | head -50", 10)
	raw = strings.TrimSpace(raw)
	if raw == "" {
		lines = append(lines, "  _Empty ruleset._")
	} else {
		lines = append(lines, "```")
		lines = append(lines, raw)
		lines = append(lines, "```")
	}

	return c.api.SendLongMessage(msg.ChatID, strings.Join(lines, "\n"), 3500)
}
