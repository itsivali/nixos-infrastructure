package services

import (
	"fmt"
	"os"
	"strings"
)

// PlatformService provides platform state engine, events, plugins, and inventory.
type PlatformService struct {
	runner  *Runner
	repoDir string
}

// NewPlatformService creates a new PlatformService.
func NewPlatformService(runner *Runner, repoDir string) *PlatformService {
	return &PlatformService{runner: runner, repoDir: repoDir}
}

// Health returns system health from ivali CLI.
func (s *PlatformService) Health() string {
	return s.runner.Run("ivali health --system 2>&1 || echo 'ivali not available'", 30)
}

// Status returns repository status from ivali CLI.
func (s *PlatformService) Status() string {
	return s.runner.Run("ivali status 2>&1 || echo 'ivali not available'", 30)
}

// Events returns recent event history.
func (s *PlatformService) Events() string {
	output := s.runner.Run("ivali status 2>&1 | grep -A 20 'Events' || echo 'No events available'", 15)
	if strings.TrimSpace(output) == "" || strings.Contains(output, "No events") {
		return ""
	}
	return output
}

// Plugins returns plugin status for all registered plugins.
func (s *PlatformService) Plugins() []PluginStatus {
	plugins := []string{
		"bitwarden", "security", "gitops", "telegram",
		"observability", "recovery", "desktop", "developer", "ai",
	}

	var result []PluginStatus
	for _, p := range plugins {
		output := strings.TrimSpace(s.runner.Run(
			fmt.Sprintf("ivali health --system 2>&1 | grep -i '%s' || echo 'unknown'", p), 5))
		loaded := output != "" && output != "unknown"
		result = append(result, PluginStatus{
			Name:   p,
			Loaded: loaded,
			Detail: output,
		})
	}
	return result
}

// PluginStatus represents a single plugin's status.
type PluginStatus struct {
	Name   string
	Loaded bool
	Detail string
}

// Inventory returns host inventory from ivali CLI.
func (s *PlatformService) Inventory() string {
	return s.runner.Run("ivali inventory 2>&1 || echo 'ivali not available'", 30)
}

// Doctor runs system diagnostics.
func (s *PlatformService) Doctor() string {
	return s.runner.Run("ivali doctor 2>&1 || echo 'ivali not available'", 60)
}

// Scan runs a repository scan.
func (s *PlatformService) Scan() string {
	return s.runner.Run("ivali scan 2>&1 || echo 'ivali not available'", 30)
}

// Suggest runs repository improvement analysis.
func (s *PlatformService) Suggest() string {
	return s.runner.Run("ivali suggest 2>&1 || echo 'ivali not available'", 60)
}

// GraphTree returns the module import tree.
func (s *PlatformService) GraphTree() string {
	return s.runner.Run("ivali graph tree 2>&1 || echo 'ivali not available'", 30)
}

// Search runs a semantic repository search.
func (s *PlatformService) Search(query string) string {
	if query == "" {
		return ""
	}
	return s.runner.Run(fmt.Sprintf("ivali search %s 2>&1 || echo 'ivali not available'", query), 30)
}

// JournalErrors returns recent journald error entries.
func (s *PlatformService) JournalErrors() string {
	return s.runner.Run("journalctl -b --no-pager -p err -n 50 2>/dev/null || echo 'journalctl not available'", 15)
}

// JournalService returns logs for a specific systemd service.
func (s *PlatformService) JournalService(name string) string {
	return s.runner.Run(
		fmt.Sprintf("journalctl -u %s -n 50 --no-pager 2>/dev/null || echo 'service not found'", name), 15)
}

// NetworkStatus returns combined network information.
func (s *PlatformService) NetworkStatus() NetworkInfo {
	info := NetworkInfo{}

	info.Hostname = strings.TrimSpace(s.runner.Run("hostname", 5))
	info.DefaultIP = strings.TrimSpace(s.runner.Run(
		"ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'", 5))
	info.DNS = strings.TrimSpace(s.runner.Run(
		"resolvectl status 2>/dev/null | head -5 || cat /etc/resolv.conf 2>/dev/null | head -5", 5))

	upIFaces := strings.TrimSpace(s.runner.Run(
		"ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | grep -v lo | head -10", 5))
	info.Interfaces = upIFaces

	info.Gateway = strings.TrimSpace(s.runner.Run(
		"ip route show default 2>/dev/null | awk '{print $3}'", 5))

	return info
}

// NetworkInfo holds parsed network status.
type NetworkInfo struct {
	Hostname   string
	DefaultIP  string
	DNS        string
	Interfaces string
	Gateway    string
}

// AIService provides AI system status and routing.
type AIService struct {
	runner  *Runner
	repoDir string
}

// NewAIService creates a new AIService.
func NewAIService(runner *Runner, repoDir string) *AIService {
	return &AIService{runner: runner, repoDir: repoDir}
}

// Status returns the status of all AI systems.
func (s *AIService) Status() AIStatus {
	status := AIStatus{}

	// OpenCode
	opencodePath := s.repoDir + "/.opencode"
	if _, err := os.Stat(opencodePath); err == nil {
		status.OpenCode = "configured"
	} else {
		status.OpenCode = "not configured"
	}

	// OpenHands
	oh := strings.TrimSpace(s.runner.Run(
		"openhands --version 2>/dev/null | head -1 || docker ps --filter name=openhands --format '{{.Status}}' 2>/dev/null | head -1 || echo not running", 8))
	if oh == "" {
		oh = "not running"
	}
	status.OpenHands = oh

	// Knowledge base
	kbPath := s.repoDir + "/opencode/README.md"
	if _, err := os.Stat(kbPath); err == nil {
		status.KnowledgeBase = "available"
	} else {
		status.KnowledgeBase = "not found"
	}

	return status
}

// AIStatus holds AI system status information.
type AIStatus struct {
	OpenCode     string
	OpenHands    string
	KnowledgeBase string
}

// RouteTask routes a task description to the appropriate AI system.
func (s *AIService) RouteTask(description string) string {
	return "opencode"
}
