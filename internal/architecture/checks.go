package architecture

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// ─── Check 1: Forbidden Imports ─────────────────────────────────────────────

// checkForbiddenImports verifies that no domain imports from a forbidden domain.
func (l *Linter) checkForbiddenImports() []Violation {
	var violations []Violation

	depsPath := filepath.Join(l.RepoRoot, "architecture", "dependencies.yaml")
	deps, err := l.loadDependencies(depsPath)
	if err != nil {
		violations = append(violations, Violation{
			Check:    "forbidden_imports",
			Severity: SeverityViolation,
			Message:  fmt.Sprintf("failed to load dependencies manifest: %v", err),
		})
		return violations
	}

	// Use separate slices to avoid append aliasing issues
	allEntries := make([]DependencyEntry, 0, len(deps.NixImports)+len(deps.ScriptReferences)+len(deps.SOPSReferences))
	allEntries = append(allEntries, deps.NixImports...)
	allEntries = append(allEntries, deps.ScriptReferences...)
	allEntries = append(allEntries, deps.SOPSReferences...)

	for _, entry := range allEntries {
		sourceDomain := l.pathToDomain(entry.Source)
		targetDomain := l.resolveDomainFromTarget(entry.Target)

		if sourceDomain == "" || targetDomain == "" {
			continue
		}

		if sourceDomain == targetDomain {
			continue
		}

		if l.isException("forbidden_imports", sourceDomain, targetDomain) {
			continue
		}

		domain := l.Domains.Domains[sourceDomain]
		if l.isForbidden(domain, targetDomain) {
			violations = append(violations, Violation{
				Check:    "forbidden_imports",
				Severity: SeverityViolation,
				Message:  fmt.Sprintf("%s cannot depend on %s", sourceDomain, targetDomain),
				Source:   entry.Source,
				Target:   entry.Target,
			})
		}
	}

	return violations
}

// isForbidden checks if a target domain is in the source domain's forbidden list.
func (l *Linter) isForbidden(domain Domain, targetDomain string) bool {
	for _, forbidden := range domain.ForbiddenDependencies {
		if forbidden == "*" {
			return true
		}
		if forbidden == targetDomain {
			return true
		}
		// Check wildcard patterns like "runtime.*"
		if strings.HasSuffix(forbidden, ".*") {
			prefix := strings.TrimSuffix(forbidden, ".*")
			if strings.HasPrefix(targetDomain, prefix) {
				return true
			}
		}
	}
	return false
}

// resolveDomainFromTarget resolves a target path/string to a domain name.
func (l *Linter) resolveDomainFromTarget(target string) string {
	// First try exact match on domain name
	if _, ok := l.Domains.Domains[target]; ok {
		return target
	}

	// Handle domain-style targets like "shared.theme/foo.nix"
	if strings.Contains(target, ".") {
		for name := range l.Domains.Domains {
			if strings.HasPrefix(target, name+"/") || strings.HasPrefix(target, name+".") {
				return name
			}
		}
	}

	// Handle path-style targets
	for name, domain := range l.Domains.Domains {
		for _, path := range domain.Paths {
			if strings.HasPrefix(target, path) {
				return name
			}
		}
	}

	return ""
}

// ─── Check 2: Circular Dependencies ────────────────────────────────────────

// checkCircularDependencies builds a dependency graph and detects cycles.
func (l *Linter) checkCircularDependencies() []Violation {
	var violations []Violation

	depsPath := filepath.Join(l.RepoRoot, "architecture", "dependencies.yaml")
	deps, err := l.loadDependencies(depsPath)
	if err != nil {
		return violations
	}

	// Build adjacency list from domain names
	graph := make(map[string][]string)

	allEntries := make([]DependencyEntry, 0, len(deps.NixImports)+len(deps.ScriptReferences))
	allEntries = append(allEntries, deps.NixImports...)
	allEntries = append(allEntries, deps.ScriptReferences...)

	for _, entry := range allEntries {
		src := l.pathToDomain(entry.Source)
		tgt := l.resolveDomainFromTarget(entry.Target)
		if src != "" && tgt != "" && src != tgt {
			graph[src] = append(graph[src], tgt)
		}
	}

	for _, entry := range deps.OptionNamespaceReads {
		src := l.pathToDomain(entry.Source)
		tgt := l.resolveDomainFromTarget(entry.Target)
		if src != "" && tgt != "" && src != tgt {
			graph[src] = append(graph[src], tgt)
		}
	}

	// DFS cycle detection
	visited := make(map[string]bool)
	inStack := make(map[string]bool)
	path := []string{}

	var dfs func(node string)
	dfs = func(node string) {
		if inStack[node] {
			// Found cycle
			cycleStart := -1
			for i, p := range path {
				if p == node {
					cycleStart = i
					break
				}
			}
			if cycleStart >= 0 {
				cycle := append(path[cycleStart:], node)
				violations = append(violations, Violation{
					Check:    "circular_dependencies",
					Severity: SeverityViolation,
					Message:  fmt.Sprintf("Circular dependency: %s", strings.Join(cycle, " -> ")),
				})
			}
			return
		}
		if visited[node] {
			return
		}

		visited[node] = true
		inStack[node] = true
		path = append(path, node)

		for _, neighbor := range graph[node] {
			dfs(neighbor)
		}

		path = path[:len(path)-1]
		inStack[node] = false
	}

	for node := range graph {
		dfs(node)
	}

	return violations
}

// ─── Check 3: Cross-Domain Filesystem Access ───────────────────────────────

// checkFilesystemBoundaries detects cross-domain filesystem access.
func (l *Linter) checkFilesystemBoundaries() []Violation {
	var violations []Violation

	nixFiles, err := l.nixFiles()
	if err != nil {
		return violations
	}

	// Known state paths and their owners
	stateOwners := map[string]string{
		"/var/lib/valkey":               "runtime.services",
		"/var/lib/ivali-bot":            "runtime.services",
		"/var/lib/security-scanner":     "platform.security",
		"/var/lib/deployment-health":    "runtime.recovery",
		"/var/lib/observability":        "runtime.observability",
		"/var/lib/health-endpoint":      "runtime.observability",
		"/var/lib/prometheus":           "runtime.observability",
		"/var/lib/loki":                 "runtime.observability",
		"/var/lib/attic":                "runtime.cache",
		"/var/lib/gitlab-runner-health": "runtime.ci",
		"/var/lib/tailscale-metrics":    "platform.security",
		"/var/lib/gitops":               "runtime.automation",
	}

	for _, file := range nixFiles {
		domain := l.pathToDomain(file)
		if domain == "" {
			continue
		}

		content, err := os.ReadFile(file)
		if err != nil {
			continue
		}

		scanner := bufio.NewScanner(strings.NewReader(string(content)))
		lineNum := 0
		for scanner.Scan() {
			lineNum++
			line := scanner.Text()

			matches := filesystemPathPattern.FindStringSubmatch(line)
			if matches == nil {
				continue
			}

			path := matches[1]
			owner, knownOwner := stateOwners[path]
			if !knownOwner {
				continue
			}

			// Check if the domain is accessing another domain's state
			if !strings.HasPrefix(domain, owner) && !strings.HasPrefix(owner, domain) {
				if l.isException("filesystem_boundaries", file, path) {
					continue
				}

				violations = append(violations, Violation{
					Check:    "filesystem_boundaries",
					Severity: SeverityQuestionable,
					Message:  fmt.Sprintf("%s accesses %s (owned by %s)", domain, path, owner),
					Source:   domain,
					Target:   path,
					File:     file,
					Line:     lineNum,
				})
			}
		}
	}

	return violations
}

// ─── Check 4: Duplicate Configuration ──────────────────────────────────────

// checkDuplicateOwnership detects duplicate systemd service ownership.
func (l *Linter) checkDuplicateOwnership() []Violation {
	var violations []Violation

	nixFiles, err := l.nixFiles()
	if err != nil {
		return violations
	}

	// Track systemd service definitions
	type serviceDef struct {
		file   string
		line   int
		domain string
	}
	services := make(map[string][]serviceDef)

	for _, file := range nixFiles {
		domain := l.pathToDomain(file)
		if domain == "" {
			continue
		}

		content, err := os.ReadFile(file)
		if err != nil {
			continue
		}

		scanner := bufio.NewScanner(strings.NewReader(string(content)))
		lineNum := 0
		servicePattern := regexp.MustCompile(`systemd\.services\.([\w-]+)\.`)
		for scanner.Scan() {
			lineNum++
			line := scanner.Text()
			matches := servicePattern.FindStringSubmatch(line)
			if matches != nil {
				svcName := matches[1]
				services[svcName] = append(services[svcName], serviceDef{
					file:   file,
					line:   lineNum,
					domain: domain,
				})
			}
		}
	}

	// Report services defined in multiple domains
	for svcName, defs := range services {
		domains := make(map[string]bool)
		for _, d := range defs {
			domains[d.domain] = true
		}
		if len(domains) > 1 {
			domainList := make([]string, 0, len(domains))
			for d := range domains {
				domainList = append(domainList, d)
			}
			violations = append(violations, Violation{
				Check:    "duplicate_ownership",
				Severity: SeverityQuestionable,
				Message:  fmt.Sprintf("Service %s defined in multiple domains: %s", svcName, strings.Join(domainList, ", ")),
				Source:   strings.Join(domainList, " vs "),
			})
		}
	}

	return violations
}

// ─── Check 5: Undeclared Dependencies ─────────────────────────────────────

// checkUndeclaredDependencies detects scripts using tools without declaring them.
func (l *Linter) checkUndeclaredDependencies() []Violation {
	var violations []Violation

	scripts, err := l.shellScripts()
	if err != nil {
		return violations
	}

	// Known tool patterns that should be declared.
	// Only flag tools that are NOT typically on the system PATH via NixOS
	// systemPackages. The ivali CLI, gitlab-runner, and sendmail are
	// installed declaratively and available in script environments.
	undeclaredTools := map[string]string{}

	for _, script := range scripts {
		content, err := os.ReadFile(script)
		if err != nil {
			continue
		}

		scanner := bufio.NewScanner(strings.NewReader(string(content)))
		lineNum := 0
		for scanner.Scan() {
			lineNum++
			line := scanner.Text()

			for tool, desc := range undeclaredTools {
				// Check if the tool is used in a command context
				if strings.Contains(line, tool) &&
					!strings.Contains(line, "#") &&
					!strings.Contains(line, "echo") &&
					!strings.Contains(line, "description") {
					relPath, _ := filepath.Rel(l.RepoRoot, script)
					violations = append(violations, Violation{
						Check:    "declared_dependencies",
						Severity: SeverityQuestionable,
						Message:  fmt.Sprintf("Script uses %s (%s) without declaring it", tool, desc),
						File:     relPath,
						Line:     lineNum,
					})
					break // One violation per line
				}
			}
		}
	}

	return violations
}

// ─── Check 6: Internal API Boundaries ─────────────────────────────────────

// checkInternalAPIBoundaries detects cross-domain access to internal paths.
func (l *Linter) checkInternalAPIBoundaries() []Violation {
	var violations []Violation

	nixFiles, err := l.nixFiles()
	if err != nil {
		return violations
	}

	for _, file := range nixFiles {
		sourceDomain := l.pathToDomain(file)
		if sourceDomain == "" {
			continue
		}

		content, err := os.ReadFile(file)
		if err != nil {
			continue
		}

		scanner := bufio.NewScanner(strings.NewReader(string(content)))
		lineNum := 0
		for scanner.Scan() {
			lineNum++
			line := scanner.Text()

			// Check for imports of other domains' internal files
			for targetName, targetDomain := range l.Domains.Domains {
				if targetName == sourceDomain {
					continue
				}

				for _, internalPath := range targetDomain.Internal {
					if strings.Contains(line, internalPath) && strings.Contains(line, "import") {
						if l.isException("internal_api_boundaries", sourceDomain, targetName) {
							continue
						}

						violations = append(violations, Violation{
							Check:    "internal_api_boundaries",
							Severity: SeverityViolation,
							Message:  fmt.Sprintf("%s accesses internal path of %s: %s", sourceDomain, targetName, internalPath),
							Source:   sourceDomain,
							Target:   targetName,
							File:     file,
							Line:     lineNum,
						})
					}
				}
			}
		}
	}

	return violations
}

// ─── Check 7: Service State Ownership ──────────────────────────────────────

// checkServiceStateOwnership detects cross-service state mutation.
func (l *Linter) checkServiceStateOwnership() []Violation {
	var violations []Violation

	depsPath := filepath.Join(l.RepoRoot, "architecture", "dependencies.yaml")
	deps, err := l.loadDependencies(depsPath)
	if err != nil {
		return violations
	}

	for _, entry := range deps.CrossServiceState {
		if l.isException("service_state_ownership", entry.Source, entry.Target) {
			continue
		}

		violations = append(violations, Violation{
			Check:    "service_state_ownership",
			Severity: SeverityViolation,
			Message:  fmt.Sprintf("%s mutates state owned by %s: %s", entry.Source, entry.Owner, entry.Target),
			Source:   entry.Source,
			Target:   entry.Target,
		})
	}

	return violations
}
