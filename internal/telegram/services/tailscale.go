package services

import (
	"fmt"
	"strings"
)

// TailscaleService provides Tailscale network operations.
type TailscaleService struct {
	runner *Runner
}

// NewTailscaleService creates a new TailscaleService.
func NewTailscaleService(runner *Runner) *TailscaleService {
	return &TailscaleService{runner: runner}
}

// StatusResult holds parsed Tailscale status information.
type StatusResult struct {
	Daemon    string
	State     string
	IP        string
	Hostname  string
	DNSName   string
	Peers     string
	IsRunning bool
}

// Status retrieves comprehensive Tailscale status.
func (s *TailscaleService) Status() StatusResult {
	result := StatusResult{}

	result.Daemon = strings.TrimSpace(s.runner.Run(
		"systemctl is-active tailscaled 2>/dev/null || echo inactive", 5))

	if result.Daemon != "active" {
		return result
	}
	result.IsRunning = true

	connectivity := strings.TrimSpace(s.runner.Run(
		"tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo unknown", 10))
	switch connectivity {
	case "Running":
		result.State = "Connected"
	case "NeedsLogin":
		result.State = "Needs login"
	default:
		result.State = connectivity
	}

	result.IP = strings.TrimSpace(s.runner.Run("tailscale ip -4 2>/dev/null || echo 'unknown'", 5))
	result.Hostname = strings.TrimSpace(s.runner.Run(
		"tailscale status --json 2>/dev/null | jq -r '.Self.HostName' 2>/dev/null || echo 'unknown'", 5))
	result.DNSName = strings.TrimSpace(s.runner.Run(
		"tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' 2>/dev/null || echo 'unknown'", 5))

	peerOutput := strings.TrimSpace(s.runner.Run(
		"tailscale status 2>/dev/null | tail -n +2 | head -20 || echo 'no peers'", 10))
	result.Peers = peerOutput

	return result
}

// FormatStatus formats the Tailscale status for Telegram display.
func (s *TailscaleService) FormatStatus() []string {
	status := s.Status()
	var lines []string
	lines = append(lines, "*Tailscale Status*")
	lines = append(lines, "")
	lines = append(lines, fmt.Sprintf("*Daemon:* `%s`", status.Daemon))

	if !status.IsRunning {
		lines = append(lines, "")
		lines = append(lines, "_Tailscale daemon is not running._")
		return lines
	}

	lines = append(lines, fmt.Sprintf("*State:* `%s`", status.State))
	lines = append(lines, fmt.Sprintf("*IP:* `%s`", status.IP))
	lines = append(lines, fmt.Sprintf("*Hostname:* `%s`", status.Hostname))

	if status.DNSName != "" && status.DNSName != "unknown" {
		lines = append(lines, fmt.Sprintf("*DNS:* `%s`", status.DNSName))
	}

	lines = append(lines, "")
	lines = append(lines, "*Peers:*")
	if status.Peers == "" {
		lines = append(lines, "  _No peers connected._")
	} else {
		lines = append(lines, "```")
		lines = append(lines, status.Peers)
		lines = append(lines, "```")
	}

	return lines
}
