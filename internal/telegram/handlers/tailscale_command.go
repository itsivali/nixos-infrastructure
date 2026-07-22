package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/willisivali/nixos-infrastructure/internal/telegram"
)

// TailscaleCommand shows Tailscale network status.
type TailscaleCommand struct {
	api *telegram.API
}

func NewTailscaleCommand(config *telegram.Config) *TailscaleCommand {
	return &TailscaleCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *TailscaleCommand) Name() string                      { return "tailscale" }
func (c *TailscaleCommand) Description() string               { return "Show Tailscale status" }
func (c *TailscaleCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *TailscaleCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*Tailscale Status*")
	lines = append(lines, "")

	// Check if tailscaled is running.
	svcStatus := runCmd("systemctl is-active tailscaled 2>/dev/null || echo inactive", 5)
	svcStatus = strings.TrimSpace(svcStatus)
	lines = append(lines, fmt.Sprintf("*Daemon:* `%s`", svcStatus))

	if svcStatus != "active" {
		lines = append(lines, "")
		lines = append(lines, "_Tailscale daemon is not running._")
		return c.api.SendMarkdown(msg.ChatID, strings.Join(lines, "\n"))
	}

	// Check connectivity.
	connectivity := runCmd("tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo unknown", 10)
	connectivity = strings.TrimSpace(connectivity)
	switch connectivity {
	case "Running":
		lines = append(lines, "*State:* `Connected`")
	case "NeedsLogin":
		lines = append(lines, "*State:* `Needs login`")
	default:
		lines = append(lines, fmt.Sprintf("*State:* `%s`", connectivity))
	}

	// Local IP.
	ip := runCmd("tailscale ip -4 2>/dev/null || echo 'unknown'", 5)
	ip = strings.TrimSpace(ip)
	lines = append(lines, fmt.Sprintf("*IP:* `%s`", ip))

	// Hostname.
	tsHostname := runCmd("tailscale status --json 2>/dev/null | jq -r '.Self.HostName' 2>/dev/null || echo 'unknown'", 5)
	tsHostname = strings.TrimSpace(tsHostname)
	lines = append(lines, fmt.Sprintf("*Hostname:* `%s`", tsHostname))

	// DNS name.
	dnsName := runCmd("tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' 2>/dev/null || echo 'unknown'", 5)
	dnsName = strings.TrimSpace(dnsName)
	if dnsName != "" && dnsName != "unknown" {
		lines = append(lines, fmt.Sprintf("*DNS:* `%s`", dnsName))
	}

	// Peers.
	lines = append(lines, "")
	lines = append(lines, "*Peers:*")
	peerOutput := runCmd("tailscale status 2>/dev/null | tail -n +2 | head -20 || echo 'no peers'", 10)
	peerOutput = strings.TrimSpace(peerOutput)
	if peerOutput == "" {
		lines = append(lines, "  _No peers connected._")
	} else {
		lines = append(lines, "```")
		lines = append(lines, peerOutput)
		lines = append(lines, "```")
	}

	return c.api.SendLongMessage(msg.ChatID, strings.Join(lines, "\n"), 3500)
}
