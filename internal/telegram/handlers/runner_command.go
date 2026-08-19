package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// RunnerCommand shows GitLab Runner status.
type RunnerCommand struct {
	api *telegram.API
}

func NewRunnerCommand(api *telegram.API) *RunnerCommand {
	return &RunnerCommand{api: api}
}

func (c *RunnerCommand) Name() string                      { return "runner" }
func (c *RunnerCommand) Description() string               { return "Show GitLab Runner status" }
func (c *RunnerCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *RunnerCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	var lines []string
	lines = append(lines, "*🔄 GitLab Runner Report*")
	lines = append(lines, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	// Read reconcile state
	reconcileState := readJSONFile("/var/lib/gitlab-runner/reconcile-state.json")
	if reconcileState != nil {
		lines = append(lines, "")
		lines = append(lines, "*Last Reconcile:*")
		lines = append(lines, fmt.Sprintf("  Time: %s", getString(reconcileState, "timestamp")))
		lines = append(lines, fmt.Sprintf("  Trigger: %s", getString(reconcileState, "trigger")))
		result := getString(reconcileState, "result")
		if result == "success" {
			lines = append(lines, "  Result: ✅ success")
		} else {
			lines = append(lines, fmt.Sprintf("  Result: ❌ %s", result))
		}
		lines = append(lines, fmt.Sprintf("  Duration: %ds", getInt(reconcileState, "duration_seconds")))

		// Steps
		if steps, ok := reconcileState["steps"].([]interface{}); ok && len(steps) > 0 {
			lines = append(lines, "")
			lines = append(lines, "  Steps:")
			for _, step := range steps {
				if s, ok := step.(map[string]interface{}); ok {
					name := getString(s, "name")
					status := getString(s, "status")
					if status == "ok" {
						lines = append(lines, fmt.Sprintf("    ✅ %s", name))
					} else {
						errMsg := getString(s, "error")
						if errMsg != "" {
							lines = append(lines, fmt.Sprintf("    ❌ %s: %s", name, errMsg))
						} else {
							lines = append(lines, fmt.Sprintf("    ❌ %s", name))
						}
					}
				}
			}
		}
	} else {
		lines = append(lines, "")
		lines = append(lines, "  No reconcile data available")
	}

	// Read health state
	lines = append(lines, "")
	lines = append(lines, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	healthState := readJSONFile("/var/lib/gitlab-runner/health-state.json")
	if healthState != nil {
		lines = append(lines, "*Health Status:*")
		lines = append(lines, fmt.Sprintf("  Time: %s", getString(healthState, "timestamp")))

		if checks, ok := healthState["checks"].(map[string]interface{}); ok {
			pass := getInt(checks, "pass")
			warn := getInt(checks, "warn")
			fail := getInt(checks, "fail")
			lines = append(lines, fmt.Sprintf("  Checks: %d pass, %d warn, %d fail", pass, warn, fail))
		}

		if details, ok := healthState["details"].([]interface{}); ok {
			lines = append(lines, "")
			lines = append(lines, "  Details:")
			for _, d := range details {
				if check, ok := d.(map[string]interface{}); ok {
					name := getString(check, "name")
					status := getString(check, "status")
					message := getString(check, "message")
					icon := "❓"
					switch status {
					case "pass":
						icon = "✅"
					case "warn":
						icon = "⚠️"
					case "fail":
						icon = "❌"
					}
					lines = append(lines, fmt.Sprintf("    %s %s: %s", icon, name, message))
				}
			}
		}
	} else {
		lines = append(lines, "  No health data available")
	}

	return c.api.SendLongMessage(msg.ChatID, strings.Join(lines, "\n"), 3500)
}

// readJSONFile reads and parses a JSON file.
func readJSONFile(path string) map[string]interface{} {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var result map[string]interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		return nil
	}
	return result
}

// getString extracts a string value from a JSON map.
func getString(m map[string]interface{}, key string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// getInt extracts an integer value from a JSON map.
func getInt(m map[string]interface{}, key string) int {
	if v, ok := m[key]; ok {
		switch n := v.(type) {
		case float64:
			return int(n)
		case int:
			return n
		}
	}
	return 0
}
