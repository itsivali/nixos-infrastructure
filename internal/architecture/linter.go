// Package architecture implements the architectural governance linter.
// It reads the architecture manifest (domains.yaml, dependencies.yaml,
// exceptions.yaml) and validates that the repository complies with
// declared domain boundaries, dependency rules, and state ownership.
package architecture

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Severity levels for violations.
type Severity string

const (
	SeverityViolation    Severity = "VIOLATION"
	SeverityQuestionable Severity = "QUESTIONABLE"
	SeverityAllowed      Severity = "ALLOWED"
)

// Violation represents a single architectural violation found by a check.
type Violation struct {
	Check    string   `json:"check"`
	Severity Severity `json:"severity"`
	Message  string   `json:"message"`
	Source   string   `json:"source"`
	Target   string   `json:"target,omitempty"`
	File     string   `json:"file,omitempty"`
	Line     int      `json:"line,omitempty"`
}

// Result holds the outcome of running all architecture checks.
type Result struct {
	Passed     bool         `json:"passed"`
	Violations []Violation  `json:"violations"`
	Summary    CheckSummary `json:"summary"`
}

// CheckSummary counts passes and failures per check.
type CheckSummary struct {
	ChecksRun            int              `json:"checks_run"`
	ChecksPassed         int              `json:"checks_passed"`
	TotalViolations      int              `json:"total_violations"`
	ViolationsBySeverity map[Severity]int `json:"violations_by_severity"`
}

// Linter is the main architecture linter.
type Linter struct {
	RepoRoot   string
	Domains    *DomainManifest
	Exceptions *ExceptionManifest
	Verbose    bool
}

// New creates a new Linter for the given repository root.
func New(repoRoot string) (*Linter, error) {
	l := &Linter{RepoRoot: repoRoot}

	domainsPath := filepath.Join(repoRoot, "architecture", "domains.yaml")
	if err := l.loadDomains(domainsPath); err != nil {
		return nil, fmt.Errorf("loading domains manifest: %w", err)
	}

	exceptionsPath := filepath.Join(repoRoot, "architecture", "exceptions.yaml")
	if err := l.loadExceptions(exceptionsPath); err != nil {
		return nil, fmt.Errorf("loading exceptions manifest: %w", err)
	}

	return l, nil
}

// Run executes all architecture checks and returns the result.
func (l *Linter) Run() *Result {
	result := &Result{
		Passed:     true,
		Violations: []Violation{},
		Summary: CheckSummary{
			ViolationsBySeverity: make(map[Severity]int),
		},
	}

	checks := []struct {
		name string
		fn   func() []Violation
	}{
		{"forbidden_imports", l.checkForbiddenImports},
		{"circular_dependencies", l.checkCircularDependencies},
		{"filesystem_boundaries", l.checkFilesystemBoundaries},
		{"duplicate_ownership", l.checkDuplicateOwnership},
		{"declared_dependencies", l.checkUndeclaredDependencies},
		{"internal_api_boundaries", l.checkInternalAPIBoundaries},
		{"service_state_ownership", l.checkServiceStateOwnership},
	}

	result.Summary.ChecksRun = len(checks)

	for _, check := range checks {
		violations := check.fn()
		if len(violations) == 0 {
			result.Summary.ChecksPassed++
		}
		result.Violations = append(result.Violations, violations...)
	}

	for _, v := range result.Violations {
		result.Summary.TotalViolations++
		result.Summary.ViolationsBySeverity[v.Severity]++
	}

	// Only VIOLATION severity fails the check. QUESTIONABLE is a warning.
	if result.Summary.ViolationsBySeverity[SeverityViolation] > 0 {
		result.Passed = false
	}

	return result
}

// pathToDomain maps a file path to its domain using the domains manifest.
func (l *Linter) pathToDomain(path string) string {
	// Convert relative paths to absolute
	absPath := path
	if !filepath.IsAbs(path) {
		absPath = filepath.Join(l.RepoRoot, path)
	}

	relPath, err := filepath.Rel(l.RepoRoot, absPath)
	if err != nil {
		return ""
	}

	bestMatch := ""
	bestLen := 0

	for _, domain := range l.Domains.Domains {
		for _, domainPath := range domain.Paths {
			if strings.HasPrefix(relPath, domainPath) && len(domainPath) > bestLen {
				bestMatch = domain.Name
				bestLen = len(domainPath)
			}
		}
	}

	return bestMatch
}

// nixFiles returns all .nix files under root, excluding .git.
func (l *Linter) nixFiles() ([]string, error) {
	var files []string
	err := filepath.Walk(l.RepoRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && info.Name() == ".git" {
			return filepath.SkipDir
		}
		if info.IsDir() && info.Name() == "architecture" {
			return filepath.SkipDir
		}
		if !info.IsDir() && strings.HasSuffix(path, ".nix") {
			files = append(files, path)
		}
		return nil
	})
	return files, err
}

// shellScripts returns all .sh files under scripts/.
func (l *Linter) shellScripts() ([]string, error) {
	var files []string
	scriptsDir := filepath.Join(l.RepoRoot, "scripts")
	if _, err := os.Stat(scriptsDir); os.IsNotExist(err) {
		return files, nil
	}
	err := filepath.Walk(scriptsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && strings.HasSuffix(path, ".sh") {
			files = append(files, path)
		}
		return nil
	})
	return files, err
}

// FormatViolation returns a human-readable violation string.
func FormatViolation(v Violation) string {
	msg := fmt.Sprintf("[%s] %s: %s", v.Severity, v.Check, v.Message)
	if v.Source != "" {
		msg += fmt.Sprintf("\n  Source: %s", v.Source)
	}
	if v.Target != "" {
		msg += fmt.Sprintf("\n  Target: %s", v.Target)
	}
	if v.File != "" {
		loc := v.File
		if v.Line > 0 {
			loc = fmt.Sprintf("%s:%d", v.File, v.Line)
		}
		msg += fmt.Sprintf("\n  File: %s", loc)
	}
	return msg
}

// isException checks if a source-target pair is covered by an documented exception.
func (l *Linter) isException(checkName, source, target string) bool {
	for _, exc := range l.Exceptions.Exceptions {
		if exc.Status == "needs_resolution" {
			continue // Don't豁免需要解决的异常
		}
		if strings.Contains(source, exc.Source) || strings.Contains(exc.Source, source) {
			if strings.Contains(target, exc.Target) || strings.Contains(exc.Target, target) {
				return true
			}
		}
	}
	return false
}

// filesystemPathPattern matches references to system paths.
var filesystemPathPattern = regexp.MustCompile(`(/var/lib/[\w-]+|/run/[\w-]+|/etc/[\w-]+)`)
