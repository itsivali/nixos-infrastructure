package services

import (
	"fmt"

	"golang.org/x/text/cases"
	"golang.org/x/text/language"

	"github.com/itsivali/nixos-infrastructure/internal/security"
)

// SecurityService provides security scanning and status.
type SecurityService struct {
	runner *Runner
}

// NewSecurityService creates a new SecurityService.
func NewSecurityService(runner *Runner) *SecurityService {
	return &SecurityService{runner: runner}
}

// FullScanResult holds the formatted result of a security scan.
type FullScanResult struct {
	Lines   []string
	Score   string
	Success bool
}

// FullScan runs a complete security scan and formats the results.
func (s *SecurityService) FullScan() FullScanResult {
	result, err := security.RunFullScan()
	if err != nil {
		return FullScanResult{
			Lines:   []string{fmt.Sprintf("*Security scan failed:* `%s`", err)},
			Success: false,
		}
	}

	var lines []string
	lines = append(lines, "*Security Status*")
	lines = append(lines, "")

	for _, cat := range result.Categories {
		icon := "✅"
		if !cat.Pass {
			icon = "❌"
		}
		lines = append(lines, fmt.Sprintf("*%s %s*", icon, cases.Title(language.Und).String(cat.Name)))
		for _, check := range cat.Checks {
			checkIcon := "  ✅"
			if !check.Pass {
				if check.Severity == "critical" || check.Severity == "high" {
					checkIcon = "  ❌"
				} else {
					checkIcon = "  ⚠️"
				}
			}
			lines = append(lines, fmt.Sprintf("%s %s: `%s`", checkIcon, check.Name, check.Message))
		}
		lines = append(lines, "")
	}

	lines = append(lines, fmt.Sprintf("_Score: %s_", security.ScoreFromResult(result)))

	return FullScanResult{
		Lines:   lines,
		Score:   security.ScoreFromResult(result),
		Success: true,
	}
}

// SecuritySummary runs a scan and returns a compact summary for menus.
func (s *SecurityService) SecuritySummary() FullScanResult {
	result, err := security.RunFullScan()
	if err != nil {
		return FullScanResult{
			Lines:   []string{fmt.Sprintf("*Security scan failed:* `%s`", err)},
			Success: false,
		}
	}

	var lines []string
	lines = append(lines, "🛡️ *Security Status*")
	lines = append(lines, "")

	for _, cat := range result.Categories {
		icon := "✅"
		if !cat.Pass {
			icon = "❌"
		}
		lines = append(lines, fmt.Sprintf("*%s %s*", icon, cases.Title(language.Und).String(cat.Name)))
		for _, check := range cat.Checks {
			checkIcon := "  ✅"
			if !check.Pass {
				if check.Severity == "critical" || check.Severity == "high" {
					checkIcon = "  ❌"
				} else {
					checkIcon = "  ⚠️"
				}
			}
			lines = append(lines, fmt.Sprintf("%s %s", checkIcon, check.Name))
		}
		lines = append(lines, "")
	}

	lines = append(lines, fmt.Sprintf("_Score: %s_", security.ScoreFromResult(result)))

	return FullScanResult{
		Lines:   lines,
		Score:   security.ScoreFromResult(result),
		Success: true,
	}
}
