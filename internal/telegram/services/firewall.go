package services

import (
	"fmt"
	"regexp"
	"strings"
)

// FirewallService provides nftables firewall operations.
type FirewallService struct {
	runner *Runner
}

// NewFirewallService creates a new FirewallService.
func NewFirewallService(runner *Runner) *FirewallService {
	return &FirewallService{runner: runner}
}

// StatusResult holds parsed firewall status information.
type FirewallStatusResult struct {
	Version    string
	RuleCount  string
	TableCount string
	Policies   []HookPolicy
	Ruleset    string
	Available  bool
}

// HookPolicy represents a firewall hook policy.
type HookPolicy struct {
	Hook   string
	Policy string
}

// Status retrieves comprehensive firewall status.
func (s *FirewallService) Status() FirewallStatusResult {
	result := FirewallStatusResult{}

	check := strings.TrimSpace(s.runner.Run("nft --version 2>/dev/null || echo 'nft not available'", 5))
	if strings.Contains(check, "not available") {
		return result
	}
	result.Available = true
	result.Version = check

	result.RuleCount = strings.TrimSpace(s.runner.Run(
		"nft list ruleset 2>/dev/null | grep -c '^\t' || echo 0", 10))
	result.TableCount = strings.TrimSpace(s.runner.Run(
		"nft list tables 2>/dev/null | grep -c '^table' || echo 0", 10))

	policies := strings.TrimSpace(s.runner.Run(
		"nft list ruleset 2>/dev/null | grep -E 'type (ip|ip6) hook' | head -10", 10))
	if policies != "" {
		hookRe := regexp.MustCompile(`type\s+\S+\s+hook\s+(\S+).*policy\s+(\S+)`)
		for _, row := range strings.Split(policies, "\n") {
			row = strings.TrimSpace(row)
			if row == "" {
				continue
			}
			matches := hookRe.FindStringSubmatch(row)
			if len(matches) >= 3 {
				result.Policies = append(result.Policies, HookPolicy{
					Hook:   matches[1],
					Policy: matches[2],
				})
			}
		}
	}

	result.Ruleset = strings.TrimSpace(s.runner.Run(
		"nft list ruleset 2>/dev/null | head -50", 10))

	return result
}

// FormatStatus formats the firewall status for Telegram display.
func (s *FirewallService) FormatStatus() []string {
	status := s.Status()
	var lines []string
	lines = append(lines, "*Firewall Status (nftables)*")
	lines = append(lines, "")

	if !status.Available {
		lines = append(lines, "_nftables is not installed or not accessible._")
		return lines
	}

	lines = append(lines, fmt.Sprintf("*Version:* `%s`", status.Version))
	lines = append(lines, fmt.Sprintf("*Total rule lines:* `%s`", status.RuleCount))
	lines = append(lines, fmt.Sprintf("*Tables:* `%s`", status.TableCount))

	lines = append(lines, "")
	lines = append(lines, "*Default policies (hooks):*")
	if len(status.Policies) > 0 {
		for _, p := range status.Policies {
			lines = append(lines, fmt.Sprintf("  `%s` → `%s`", p.Hook, p.Policy))
		}
	} else {
		lines = append(lines, "  _No hook policies found._")
	}

	lines = append(lines, "")
	lines = append(lines, "*Ruleset (first 50 lines):*")
	if status.Ruleset == "" {
		lines = append(lines, "  _Empty ruleset._")
	} else {
		lines = append(lines, "```")
		lines = append(lines, status.Ruleset)
		lines = append(lines, "```")
	}

	return lines
}
