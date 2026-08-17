package architecture

import (
	"os"
	"path/filepath"
	"testing"
)

// testRepo creates a temporary test repository with the given structure.
func testRepo(t *testing.T, files map[string]string) string {
	t.Helper()
	dir := t.TempDir()

	// Create architecture manifest files
	archDir := filepath.Join(dir, "architecture")
	if err := os.MkdirAll(archDir, 0o755); err != nil {
		t.Fatal(err)
	}

	for path, content := range files {
		fullPath := filepath.Join(dir, path)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(fullPath, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	return dir
}

func TestLinterCleanArchitecture(t *testing.T) {
	files := map[string]string{
		"architecture/domains.yaml": `
domains:
  core.system:
    level: 0
    paths: ["system/"]
    public: ["system/default.nix"]
    internal: ["system/nix.nix"]
    allowed_dependencies: []
    forbidden_dependencies: ["*"]

  platform.networking:
    level: 1
    paths: ["networking/"]
    public: ["networking/default.nix"]
    internal: []
    allowed_dependencies: ["core.*"]
    forbidden_dependencies: ["*"]
`,
		"architecture/dependencies.yaml": `
nix_imports: []
script_references: []
sops_references: []
option_namespace_reads: []
filesystem_access: []
cross_service_state: []
`,
		"architecture/exceptions.yaml": `
exceptions: []
`,
		"system/default.nix":     `{ ... }: { }`,
		"networking/default.nix": `{ ... }: { }`,
	}

	dir := testRepo(t, files)
	linter, err := New(dir)
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}

	result := linter.Run()
	if !result.Passed {
		t.Errorf("expected PASS, got FAIL with %d violations", result.Summary.TotalViolations)
		for _, v := range result.Violations {
			t.Logf("  %s", FormatViolation(v))
		}
	}
}

func TestLinterForbiddenImport(t *testing.T) {
	files := map[string]string{
		"architecture/domains.yaml": `
domains:
  core.system:
    level: 0
    paths: ["system/"]
    public: ["system/default.nix"]
    internal: []
    allowed_dependencies: []
    forbidden_dependencies: ["*"]

  runtime.services:
    level: 3
    paths: ["services/"]
    public: ["services/default.nix"]
    internal: ["services/bot/"]
    allowed_dependencies: ["core.*"]
    forbidden_dependencies: ["*"]
`,
		"architecture/dependencies.yaml": `
nix_imports:
  - source: services/bot/ivali-bot-go.nix
    target: core.system/nix.nix
    type: import
    severity: violation
script_references: []
sops_references: []
option_namespace_reads: []
filesystem_access: []
cross_service_state: []
`,
		"architecture/exceptions.yaml": `
exceptions: []
`,
		"services/bot/ivali-bot-go.nix": `{ ... }: { }`,
		"system/nix.nix":                `{ ... }: { }`,
	}

	dir := testRepo(t, files)
	linter, err := New(dir)
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}

	// Debug: print loaded domains
	for name, domain := range linter.Domains.Domains {
		t.Logf("Domain %q: paths=%v, forbidden=%v", name, domain.Paths, domain.ForbiddenDependencies)
	}

	// Debug: test path resolution
	srcDomain := linter.pathToDomain(filepath.Join(dir, "services/bot/ivali-bot-go.nix"))
	t.Logf("Source domain for services/bot/ivali-bot-go.nix: %q", srcDomain)
	tgtDomain := linter.resolveDomainFromTarget("core.system/nix.nix")
	t.Logf("Target domain for core.system/nix.nix: %q", tgtDomain)

	result := linter.Run()
	t.Logf("Result passed: %v, violations: %d", result.Passed, len(result.Violations))
	for _, v := range result.Violations {
		t.Logf("Violation: %s", FormatViolation(v))
	}

	if result.Passed {
		t.Error("expected FAIL for forbidden import, got PASS")
	}

	found := false
	for _, v := range result.Violations {
		if v.Check == "forbidden_imports" {
			found = true
			break
		}
	}
	if !found {
		t.Error("expected forbidden_imports violation, none found")
	}
}

func TestLinterCircularDependency(t *testing.T) {
	files := map[string]string{
		"architecture/domains.yaml": `
domains:
  domain.a:
    level: 2
    paths: ["a/"]
    public: []
    internal: []
    allowed_dependencies: ["domain.b"]
    forbidden_dependencies: []

  domain.b:
    level: 2
    paths: ["b/"]
    public: []
    internal: []
    allowed_dependencies: ["domain.a"]
    forbidden_dependencies: []
`,
		"architecture/dependencies.yaml": `
nix_imports:
  - source: a/foo.nix
    target: domain.b
    type: import
    severity: violation
  - source: b/bar.nix
    target: domain.a
    type: import
    severity: violation
script_references: []
sops_references: []
option_namespace_reads: []
filesystem_access: []
cross_service_state: []
`,
		"architecture/exceptions.yaml": `
exceptions: []
`,
		"a/foo.nix": `{ ... }: { }`,
		"b/bar.nix": `{ ... }: { }`,
	}

	dir := testRepo(t, files)
	linter, err := New(dir)
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}

	result := linter.Run()
	found := false
	for _, v := range result.Violations {
		if v.Check == "circular_dependencies" {
			found = true
			break
		}
	}
	if !found {
		t.Error("expected circular_dependencies violation, none found")
	}
}

func TestLinterExceptionExemption(t *testing.T) {
	files := map[string]string{
		"architecture/domains.yaml": `
domains:
  core.system:
    level: 0
    paths: ["system/"]
    public: []
    internal: []
    allowed_dependencies: []
    forbidden_dependencies: ["*"]

  runtime.services:
    level: 3
    paths: ["services/"]
    public: []
    internal: []
    allowed_dependencies: ["core.*"]
    forbidden_dependencies: ["*"]
`,
		"architecture/dependencies.yaml": `
nix_imports:
  - source: services/bot/ci-notify.nix
    target: shared.scripts/notify.sh
    type: import
    severity: allowed
script_references: []
sops_references: []
option_namespace_reads: []
filesystem_access: []
cross_service_state: []
`,
		"architecture/exceptions.yaml": `
exceptions:
  - id: EXC-001
    source: runtime.services/bot
    target: shared.scripts/notify.sh
    reason: "test exception"
    owner: test
    review: "2026-11-01"
    status: active
`,
		"services/bot/ci-notify.nix": `{ ... }: { }`,
	}

	dir := testRepo(t, files)
	linter, err := New(dir)
	if err != nil {
		t.Fatalf("New() error: %v", err)
	}

	result := linter.Run()
	for _, v := range result.Violations {
		if v.Check == "forbidden_imports" && v.Source == "services/bot/ci-notify.nix" {
			t.Errorf("exception should have exempted this violation: %s", FormatViolation(v))
		}
	}
}

func TestFormatViolation(t *testing.T) {
	v := Violation{
		Check:    "test_check",
		Severity: SeverityViolation,
		Message:  "test message",
		Source:   "source.txt",
		Target:   "target.txt",
		File:     "file.nix",
		Line:     42,
	}

	output := FormatViolation(v)
	if output == "" {
		t.Error("FormatViolation returned empty string")
	}
	if !contains(output, "VIOLATION") {
		t.Error("FormatViolation missing severity")
	}
	if !contains(output, "test message") {
		t.Error("FormatViolation missing message")
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsSubstr(s, substr))
}

func containsSubstr(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
