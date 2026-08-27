package commands

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"golang.org/x/term"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/operations"
	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW CONTEXT — carries mode through all commands
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// flowCtx carries state across all flow subcommands.
type flowCtx struct {
	app     *app.App
	term    *terminal.Terminal
	repoDir string
	aiMode  bool // non-interactive: auto-confirm, structured output
}

// newFlowCtx creates a flow context from the app.
// Non-interactive mode is auto-detected: if stdin is not a terminal, prompts
// are auto-accepted and structured output is used. This allows any LLM or
// CI system to use Ivali Flow as a contract without special flags.
func newFlowCtx(a *app.App, aiMode bool) *flowCtx {
	repoDir := "."
	if a.Repo != nil && a.Repo.Root != "" {
		repoDir = a.Repo.Root
	}
	// Auto-detect: if stdin is not a terminal, force non-interactive mode
	if !term.IsTerminal(int(os.Stdin.Fd())) {
		aiMode = true
	}
	return &flowCtx{
		app:     a,
		term:    a.Term,
		repoDir: repoDir,
		aiMode:  aiMode,
	}
}

// ── Guided UX helpers ─────────────────────────────────────────────────────

func (f *flowCtx) header(title string) {
	fmt.Println()
	fmt.Println(f.term.Section(title))
	fmt.Println()
}

func (f *flowCtx) stepStart(label string) {
	fmt.Printf("  %s %s\n", f.term.Dim("┌─"), label)
}

func (f *flowCtx) stepOK(label string) {
	fmt.Printf("  %s %s %s\n", f.term.Dim("│"), f.term.Good("✓"), f.term.Code(label))
}

func (f *flowCtx) stepFail(label string) {
	fmt.Printf("  %s %s %s\n", f.term.Dim("│"), f.term.Bad("✗"), f.term.Code(label))
}

func (f *flowCtx) stepInfo(msg string) {
	fmt.Printf("  %s %s\n", f.term.Dim("│"), msg)
}

func (f *flowCtx) stepDone() {
	fmt.Printf("  %s\n\n", f.term.Dim("└─── done"))
}

func (f *flowCtx) stepFailed() {
	fmt.Printf("  %s\n\n", f.term.Dim("└─── failed"))
}

func (f *flowCtx) divider() {
	fmt.Println(f.term.Dim("  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
	fmt.Println()
}

func (f *flowCtx) nextHint(cmd string) {
	fmt.Printf("  %s\n\n", f.term.Dim("Next: "+cmd))
}

// confirm prompts the user (interactive) or auto-accepts (AI mode).
func (f *flowCtx) confirm(msg string) bool {
	if f.aiMode {
		f.stepInfo(fmt.Sprintf("%s %s", msg, f.term.Dim("(auto: non-interactive)")))
		return true
	}
	fmt.Printf("  %s %s %s\n",
		f.term.ColoredIcon("", f.term.Color.Yellow),
		msg,
		f.term.Dim("[y/N]"),
	)
	var response string
	_, _ = fmt.Scanln(&response)
	response = strings.TrimSpace(strings.ToLower(response))
	return response == "y" || response == "yes"
}

// prompt asks for text input (interactive) or returns empty (AI mode).
func (f *flowCtx) prompt(label string) string {
	if f.aiMode {
		return ""
	}
	reader := bufio.NewReader(os.Stdin)
	fmt.Printf("  %s ", label)
	input, _ := reader.ReadString('\n')
	return strings.TrimSpace(input)
}

// ── Git helpers ────────────────────────────────────────────────────────────

func extractGitLabURL(output string) string {
	for _, line := range strings.Split(output, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "https://") || strings.HasPrefix(line, "http://") {
			return line
		}
	}
	return strings.TrimSpace(output)
}

func extractIssueNum(url string) string {
	if idx := strings.LastIndex(url, "/"); idx != -1 {
		num := url[idx+1:]
		// Strip any trailing whitespace or newlines
		num = strings.TrimSpace(num)
		return num
	}
	return ""
}

func gitBranch(repoDir string) (string, error) {
	cmd := exec.Command("git", "branch", "--show-current")
	cmd.Dir = repoDir
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("not in a git repository")
	}
	return strings.TrimSpace(string(out)), nil
}

func gitUnpushed(repoDir, branch string) (string, bool) {
	cmd := exec.Command("git", "log", "origin/"+branch+"..HEAD", "--oneline")
	cmd.Dir = repoDir
	out, err := cmd.Output()
	if err != nil {
		return "", false
	}
	s := strings.TrimSpace(string(out))
	return s, s != ""
}

func gitRun(repoDir, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	if repoDir != "" {
		cmd.Dir = repoDir
	}
	out, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

// gitCommit runs git commit with mandatory Willis Ivali authorship.
func gitCommit(repoDir, msg string) (string, error) {
	cmd := exec.Command("git", "commit", "-m", msg)
	if repoDir != "" {
		cmd.Dir = repoDir
	}
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=Willis Ivali",
		"GIT_AUTHOR_EMAIL=itsivali@outlook.com",
		"GIT_COMMITTER_NAME=Willis Ivali",
		"GIT_COMMITTER_EMAIL=itsivali@outlook.com",
	)
	out, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

// runAITool tries opencode first, then falls back to freebuff.
// Both tools receive the same prompt and run in repoDir.
// Returns the tool name used and any error.
func runAITool(repoDir, prompt string) (string, error) {
	// Try opencode first
	if _, err := exec.LookPath("opencode"); err == nil {
		cmd := exec.Command("opencode", "run", prompt)
		cmd.Dir = repoDir
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err == nil {
			return "opencode", nil
		}
		// opencode failed — fall through to freebuff
	}

	// Fall back to freebuff
	if _, err := exec.LookPath("freebuff"); err == nil {
		cmd := exec.Command("freebuff", "--cwd", repoDir, prompt)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err == nil {
			return "freebuff", nil
		}
		return "freebuff", fmt.Errorf("freebuff failed")
	}

	return "", fmt.Errorf("no AI tool available (install opencode or freebuff)")
}

// buildImplementPrompt constructs a rich prompt for the AI based on change type.
func buildImplementPrompt(repoDir, changeType, description, issueNum string) string {
	// Read architecture domains for context
	domainsCtx := ""
	if data, err := os.ReadFile(filepath.Join(repoDir, "architecture", "domains.yaml")); err == nil {
		// Take first 2000 chars for context
		if len(data) > 2000 {
			domainsCtx = string(data[:2000]) + "..."
		} else {
			domainsCtx = string(data)
		}
	}

	// Read existing patterns
	patternsCtx := ""
	if data, err := os.ReadFile(filepath.Join(repoDir, "CONTRIBUTING.md")); err == nil {
		if len(data) > 1500 {
			patternsCtx = string(data[:1500]) + "..."
		} else {
			patternsCtx = string(data)
		}
	}

	base := fmt.Sprintf(`You are implementing a %s for a NixOS infrastructure repository.

Issue: #%s
Description: %s
Branch: (current branch)

Repository Architecture:
%s

Contribution Guidelines:
%s
`, changeType, issueNum, description, domainsCtx, patternsCtx)

	switch changeType {
	case "feature":
		return base + `
INSTRUCTIONS — FEATURE IMPLEMENTATION:

1. Identify which domain this feature belongs to (from the architecture manifest)
2. Create or modify files in the appropriate domain directory
3. Follow NixOS module conventions:
   - Use lib.mkEnableOption for opt-in by default
   - Use lib.mkIf for conditional configuration
   - Use absolute paths (no relative paths in Nix)
   - All modules must be disabled by default
4. Write the implementation:
   - NixOS modules: proper options, configuration, systemd services
   - Go code: proper error handling, interfaces, tests
   - Shell scripts: set -euo pipefail, absolute paths via Nix interpolation
5. Write tests:
   - Go: table-driven tests with test cases for each branch
   - Nix: evaluation tests (nix eval)
   - Shell: shellcheck compliance
6. Update documentation:
   - Add/update README.md for the module
   - Update DOCS.md if it's a significant module
7. Ensure ALL verification gates pass:
   - go build ./...
   - go test ./...
   - go vet ./...

The feature must be: production-grade, tested, documented, and follow existing patterns.
Do NOT leave any TODOs, placeholders, or stub implementations.`

	case "bugfix":
		return base + `
INSTRUCTIONS — BUGFIX IMPLEMENTATION:

1. Analyze the bug description to understand the root cause
2. Find the affected code in the repository
3. Implement the fix:
   - Minimal change that addresses the root cause
   - No unrelated changes (one logical fix per commit)
   - Preserve existing behavior for non-buggy paths
4. Write a regression test:
   - Test case that would have caught this bug
   - Test case for the correct behavior
   - Test edge cases related to the bug
5. Verify the fix:
   - Run the specific test: go test -run TestName
   - Run full test suite: go test ./...
   - Run go vet ./...
6. Update documentation if the fix changes public behavior

The fix must be: minimal, targeted, tested, and documented.
Do NOT refactor unrelated code. Do NOT add features.`

	case "module":
		return base + `
INSTRUCTIONS — NixOS/HOME MANAGER MODULE:

1. Determine module type:
   - NixOS module (system-level): place in appropriate domain under modules/nixos/
   - Home Manager module (user-level): place in appropriate domain under modules/home/
2. Create the module following conventions:
   - One module = one capability (don't mix unrelated services)
   - Opt-in by default (config.modules.<domain>.<name>.enable = false)
   - Highly parameterized using lib.mkOption and lib.mkIf
   - No hardcoded paths — use Nix string interpolation
   - No plaintext secrets — use sops-nix
3. Create the module structure:
   - default.nix — main module entry point
   - options.nix — all configuration options
   - Implementation files as needed
4. Write the module:
   - Proper NixOS option declarations
   - Systemd service configuration (if applicable)
   - Hardening parameters (DynamicUser, ProtectSystem, etc.)
   - State directory management
5. Write tests:
   - Module evaluates without error: nix eval
   - Default config works
   - Custom config works
6. Update documentation:
   - Module README.md
   - Update DOCS.md
   - Update architecture manifests if new domain
7. Ensure ALL verification gates pass:
   - nix fmt -- --check .
   - nix flake check --no-build
   - go build ./...

The module must be: production-grade, tested, documented, and follow existing patterns.
Do NOT leave any TODOs, placeholders, or stub implementations.`

	case "security":
		return base + `
INSTRUCTIONS — SECURITY HARDENING:

1. Identify the security concern from the description
2. Implement the hardening:
   - Follow principle of least privilege
   - Use systemd hardening (DynamicUser, ProtectSystem, etc.)
   - Add AppArmor profiles if needed
   - Update firewall rules if needed
   - No plaintext secrets — use sops-nix
3. Write the implementation:
   - Security modules in security/ directory
   - Systemd hardening parameters
   - Firewall rules (nftables)
   - Audit configuration
4. Write tests:
   - Verify hardening is applied
   - Verify no regressions in existing security
   - Run security scan: gosec
5. Security review checklist:
   - No secrets exposed in code or config
   - No hardcoded credentials
   - Proper SOPS integration
   - Systemd hardening applied
   - Audit logging configured
6. Update documentation:
   - Security module README
   - Update DOCS.md
7. Ensure ALL verification gates pass:
   - go build ./...
   - go test ./...
   - gosec -exclude-generated ./...

The security change must be: thorough, tested, documented, and follow security best practices.
Do NOT leave any TODOs, placeholders, or incomplete hardening.`

	case "architecture":
		return base + `
INSTRUCTIONS — ARCHITECTURE CHANGE:

1. Understand the current architecture from architecture/domains.yaml
2. Plan the change:
   - Which domains are affected?
   - What new dependencies are introduced?
   - Are there any circular dependencies?
3. Implement the change:
   - Update domain definitions in architecture/domains.yaml
   - Update ARCHITECTURE.md
   - Update ARCHITECTURE_PROGRESS.md
   - Create/update architecture exceptions if needed
4. Refactor code:
   - Move files to correct domains
   - Update imports and references
   - Remove dead code
5. Write tests:
   - Architecture linter: go run ./cmd/check-architecture/
   - Go tests: go test ./...
   - Nix evaluation: nix eval
6. Ensure no circular dependencies
7. Ensure all verification gates pass:
   - go build ./...
   - go test ./...
   - go vet ./...
   - nix flake check --no-build

The architecture change must be: well-planned, tested, documented, and follow the domain hierarchy.
Do NOT break existing functionality. Do NOT introduce circular dependencies.`

	case "docs":
		return base + `
INSTRUCTIONS — DOCUMENTATION UPDATE:

1. Identify which documentation needs updating
2. Update the relevant files:
   - DOCS.md — module documentation
   - README.md — project overview
   - CONTRIBUTING.md — contribution guidelines
   - ARCHITECTURE.md — architecture documentation
   - Module-specific README.md files
3. Ensure documentation:
   - Matches current implementation
   - Includes all options and configuration
   - Has troubleshooting steps
   - Is clear and concise
4. Verify:
   - All code examples work
   - All links are valid
   - No outdated information
5. Ensure ALL verification gates pass:
   - go build ./...
   - go vet ./...

The documentation must be: accurate, complete, and follow existing patterns.
Do NOT leave any TODOs or placeholder text.`

	default:
		return base + `
INSTRUCTIONS:

Implement the change described above. Follow all repository conventions.
Write tests, update documentation, and ensure all verification gates pass.
Do NOT leave any TODOs, placeholders, or stub implementations.`
	}
}

func cleanBranchName(s string) string {
	s = strings.ToLower(s)
	s = strings.ReplaceAll(s, " ", "-")
	s = strings.ReplaceAll(s, "_", "-")
	result := ""
	for _, c := range s {
		if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' {
			result += string(c)
		}
	}
	for strings.Contains(result, "--") {
		result = strings.ReplaceAll(result, "--", "-")
	}
	result = strings.Trim(result, "-")
	if len(result) > 50 {
		result = result[:50]
	}
	return result
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CMD FLOW — root command
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func CmdFlow(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "flow",
		Short: "Guided development workflow — issue, branch, commit, CI, deploy",
		Long: `Interactive and AI-driven GitLab workflow for NixOS infrastructure.

Every step is guided: the CLI walks you through issue → branch → validate
→ commit → push → MR → CI → merge → deploy, prompting for confirmation
at each gate.

When stdin is not a terminal (e.g., LLM or CI), all prompts are auto-accepted.
The AI makes file changes, then calls ivali flow to commit and push.

Routes:
  ivali flow start       Create issue + branch
  ivali flow run         Full pipeline: start → implement → validate → commit → push → MR → merge
  ivali flow validate    Run all verification gates
  ivali flow commit      Stage and commit with conventional message
  ivali flow push        Push branch to GitLab
  ivali flow mr          Create merge request
  ivali flow pipeline    Monitor CI pipeline status
  ivali flow merge       Merge MR (gates on CI)
  ivali flow deploy      Deploy via operations engine
  ivali flow rollback    Roll back to previous generation
  ivali flow quick       Single-shot: commit → push → MR (AI-friendly)
  ivali flow status      Show current workflow state`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(
		flowStart(a),
		flowRun(a),
		flowCommit(a),
		flowPush(a),
		flowMR(a),
		flowMerge(a),
		flowDeploy(a),
		flowValidate(a),
		flowPipeline(a),
		flowRollback(a),
		flowQuick(a),
		flowStatus(a),
	)

	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW START
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowStart(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "start [type] [description]",
		Short: "Start a new workflow (creates issue + branch + optional AI implementation)",
		Long: `Guided workflow starter with AI code generation.

Creates a GitLab issue and feature branch. With --implement, the AI (opencode or freebuff)
is called to write the actual code based on the change type and description.

The AI understands the repository architecture and writes:
  - Feature: new NixOS modules, Go code, tests, documentation
  - Bugfix: root cause analysis, fix, regression test
  - Module: new NixOS/Home Manager module with options and tests
  - Security: hardening changes with security review
  - Architecture: structural changes with manifest updates
  - Docs: documentation updates

Examples:
  ivali flow start                                    # Interactive: prompts for type + description
  ivali flow start feature "add firewall"             # Fully specified
  ivali flow start feature "add nginx" --implement    # AI writes the code`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			implement, _ := cmd.Flags().GetBool("implement")
			f := newFlowCtx(a, aiMode)
			f.header("Flow Start")

			// AI mode: auto-implement
			if aiMode {
				implement = true
			}

			// ── Step 1: Change type ──────────────────────────────────────
			changeType := ""
			if len(args) > 0 {
				changeType = args[0]
			} else {
				fmt.Println("  What type of change is this?")
				fmt.Println()
				fmt.Println("    1) feature       New feature or enhancement")
				fmt.Println("    2) bugfix        Bug fix")
				fmt.Println("    3) module        New NixOS/Home Manager module")
				fmt.Println("    4) security      Security hardening")
				fmt.Println("    5) architecture  Architecture changes")
				fmt.Println("    6) docs          Documentation")
				fmt.Println()
				reader := bufio.NewReader(os.Stdin)
				fmt.Printf("  Select (1-6): ")
				choice, _ := reader.ReadString('\n')
				choice = strings.TrimSpace(choice)
				switch choice {
				case "1":
					changeType = "feature"
				case "2":
					changeType = "bugfix"
				case "3":
					changeType = "module"
				case "4":
					changeType = "security"
				case "5":
					changeType = "architecture"
				case "6":
					changeType = "docs"
				default:
					return fmt.Errorf("invalid selection: %s", choice)
				}
			}

			validTypes := map[string]bool{
				"feature": true, "bugfix": true, "module": true,
				"security": true, "architecture": true, "docs": true,
			}
			if !validTypes[changeType] {
				return fmt.Errorf("invalid type: %s", changeType)
			}

			// Map type to label for display
			typeLabels := map[string]string{
				"feature":      "New feature or enhancement",
				"bugfix":       "Bug fix",
				"module":       "New NixOS/Home Manager module",
				"security":     "Security hardening",
				"architecture": "Architecture changes",
				"docs":         "Documentation",
			}
			typeLabel := typeLabels[changeType]

			// ── Step 2: Description ──────────────────────────────────────
			description := ""
			if len(args) > 1 {
				description = args[1]
			} else {
				fmt.Println()
				fmt.Println("  Describe what you want to do:")
				reader := bufio.NewReader(os.Stdin)
				fmt.Printf("  Description: ")
				description, _ = reader.ReadString('\n')
				description = strings.TrimSpace(description)
				if description == "" {
					return fmt.Errorf("description required")
				}
			}

			// ── Summary box ──────────────────────────────────────────────
			fmt.Println()
			fmt.Println(f.term.Dim("  ┌─────────────────────────────────────────────┐"))
			fmt.Println(f.term.Dim("  │  Summary:"))
			fmt.Printf("  │    Type:        %s\n", f.term.Code(changeType))
			fmt.Printf("  │    Label:       %s\n", f.term.Code(typeLabel))
			fmt.Printf("  │    Description: %s\n", f.term.Code(description))
			fmt.Println(f.term.Dim("  └─────────────────────────────────────────────┘"))
			fmt.Println()

			if !f.confirm("  Continue?") {
				f.stepInfo("Cancelled")
				return nil
			}

			// ── Step 3: Create GitLab issue ──────────────────────────────
			f.stepStart("Step 1: Creating GitLab issue")

			// Load template
			templatePath := filepath.Join(f.repoDir, ".gitlab", "issue_templates", changeType+".md")
			issueBody := ""
			fmt.Printf("  │  %s Loading %s template...\n", f.term.Dim("▶"), f.term.Code(changeType))
			if data, err := os.ReadFile(templatePath); err == nil {
				issueBody = string(data)
				// Fill in the description placeholder based on type
				issueBody = strings.ReplaceAll(issueBody, "<!-- What does this feature do? -->", description)
				issueBody = strings.ReplaceAll(issueBody, "<!-- What is the bug? -->", description)
				issueBody = strings.ReplaceAll(issueBody, "<!-- What capability does this module provide? -->", description)
				issueBody = strings.ReplaceAll(issueBody, "<!-- What is the security concern? -->", description)
				f.stepOK("Template loaded")
			} else {
				issueBody = fmt.Sprintf("## Description\n\n%s\n\n## Type\n\n%s", description, changeType)
				f.stepInfo("No template found — using default")
			}

			// Create issue
			issueTitle := fmt.Sprintf("[%s] %s", changeType, description)
			fmt.Printf("  │  %s Creating issue...\n", f.term.Dim("▶"))
			issueCmd := exec.Command("glab", "issue", "create",
				"--title", issueTitle,
				"--description", issueBody,
				"--label", changeType,
			)
			issueCmd.Dir = f.repoDir

			issueOut, err := issueCmd.CombinedOutput()
			if err != nil {
				f.stepFail(fmt.Sprintf("Failed to create issue: %s", string(issueOut)))
				f.stepFailed()
				return fmt.Errorf("failed to create issue: %s", string(issueOut))
			}
			issueURL := extractGitLabURL(string(issueOut))
			f.stepOK(issueURL)

			issueNum := extractIssueNum(issueURL)
			f.stepDone()

			// ── Step 4: Create branch ────────────────────────────────────
			f.stepStart("Step 2: Creating branch")
			branchName := fmt.Sprintf("%s/%s", changeType, cleanBranchName(description))
			if len(branchName) > 60 {
				branchName = branchName[:60]
			}
			fmt.Printf("  │  %s git checkout -b %s\n", f.term.Dim("▶"), f.term.Code(branchName))
			if out, err := gitRun(f.repoDir, "git", "checkout", "-b", branchName); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to create branch: %s", out)
			}
			f.stepOK(fmt.Sprintf("Branch %s created", f.term.Code(branchName)))
			f.stepDone()

			// ── Step 5: AI Implementation ──────────────────────────────
			if implement {
				f.stepStart("Step 3: AI Implementation")
				f.stepInfo("")
				f.stepInfo("  The AI will now implement the changes.")
				f.stepInfo("  It will create/modify files, write tests, and update docs.")
				f.stepInfo("")

				prompt := buildImplementPrompt(f.repoDir, changeType, description, issueNum)
				fmt.Printf("  │  %s %s\n", f.term.Dim("Prompt:"), f.term.Code(prompt[:80]+"..."))
				f.stepInfo("")

				if !f.aiMode {
					if !f.confirm("  Let AI implement this?") {
						f.stepInfo("Skipping AI implementation")
						f.stepDone()
					} else {
						f.stepInfo("Calling AI tool...")
						tool, err := runAITool(f.repoDir, prompt)
						if err != nil {
							f.stepInfo(fmt.Sprintf("  %s %v", f.term.Warn("⚠"), err))
							f.stepInfo("  You can run the AI tool manually later")
						} else {
							f.stepOK(fmt.Sprintf("AI implementation complete (via %s)", tool))
						}
						f.stepDone()
					}
				} else {
					f.stepInfo("Calling AI tool...")
					tool, err := runAITool(f.repoDir, prompt)
					if err != nil {
						f.stepInfo(fmt.Sprintf("  %s %v", f.term.Warn("⚠"), err))
						f.stepInfo("  You can run the AI tool manually later")
					} else {
						f.stepOK(fmt.Sprintf("AI implementation complete (via %s)", tool))
					}
					f.stepDone()
				}
			}

			// ── Workflow Ready ──────────────────────────────────────────
			if f.aiMode {
				f.stepStart("AI mode active")
				f.stepInfo("")
				f.stepInfo(fmt.Sprintf("  Issue #%s created: %s", f.term.Code(issueNum), issueURL))
				f.stepInfo(fmt.Sprintf("  Branch ready:     %s", f.term.Code(branchName)))
				f.stepInfo("")
				f.stepInfo("  Make your changes, then run:")
				f.stepInfo(fmt.Sprintf("    %s", f.term.Code("ivali flow quick \"description\"")))
				f.stepInfo("")
				f.stepDone()
			} else {
				f.stepStart("Workflow Ready")
				f.stepInfo("")
				f.stepInfo("  Next steps:")
				f.stepInfo("    1. Make your changes")
				f.stepInfo("    2. ivali flow validate     (run all checks)")
				f.stepInfo("    3. ivali flow commit")
				f.stepInfo("    4. ivali flow push")
				f.stepInfo("    5. ivali flow mr")
				f.stepInfo("    6. ivali flow merge        (waits for CI)")
				f.stepInfo("    7. ivali flow deploy")
				f.stepInfo("")
				f.stepInfo(fmt.Sprintf("  Shortcut: %s (single-shot commit→push→MR)", f.term.Code("ivali flow quick \"description\"")))
				f.stepDone()
			}

			// AI output
			if f.aiMode {
				result := map[string]string{
					"action":      "start",
					"type":        changeType,
					"description": description,
					"issue":       issueURL,
					"issue_num":   issueNum,
					"branch":      branchName,
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		}}

	var implement bool

	cmd.Flags().BoolVar(&implement, "implement", false, "Call AI (opencode or freebuff) to write the code for this change")
	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW VALIDATE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowValidate(a *app.App) *cobra.Command {
	var host string

	cmd := &cobra.Command{
		Use:   "validate",
		Short: "Run all verification gates locally (before commit)",
		Long: `Run the full verification pipeline before committing or pushing.

Runs the same gates as CI:
  1. nix fmt       (formatting)
  2. shellcheck     (shell lint)
  3. go build       (compilation)
  4. go vet         (static analysis)
  5. go test -race  (tests with race detector)
  6. nix flake check (flake schema)
  7. nix eval       (configuration evaluation, if --host given)
  8. gosec          (security scan)

In AI mode, runs all gates and outputs JSON results.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Validate")

			passed := 0
			failed := 0
			total := 0

			type gateEntry struct {
				name string
				fn   func() (string, error)
			}

			gates := []gateEntry{
				{"nix fmt", func() (string, error) {
					return gitRun(f.repoDir, "nix", "fmt", "--", "--check", ".")
				}},
				{"shellcheck", func() (string, error) {
					out, err := gitRun(f.repoDir, "shellcheck", "--severity=warning")
					if err != nil && strings.Contains(out, "No such file") {
						return "", nil
					}
					return out, err
				}},
				{"go build", func() (string, error) {
					return gitRun(f.repoDir, "go", "build", "./...")
				}},
				{"go vet", func() (string, error) {
					return gitRun(f.repoDir, "go", "vet", "./...")
				}},
				{"go test -race", func() (string, error) {
					return gitRun(f.repoDir, "go", "test", "-race", "-count=1", "./...")
				}},
				{"nix flake check", func() (string, error) {
					return gitRun(f.repoDir, "nix", "flake", "check", "--no-build")
				}},
			}

			if host != "" {
				h := host
				gates = append(gates, gateEntry{
					fmt.Sprintf("nix eval (host=%s)", h), func() (string, error) {
						return gitRun(f.repoDir, "nix", "eval",
							fmt.Sprintf(".#nixosConfigurations.%s.config.system.build.toplevel.name", h))
					},
				})
			}

			gates = append(gates, gateEntry{"gosec", func() (string, error) {
				return gitRun(f.repoDir, "gosec", "-exclude-generated", "./...")
			}})

			for _, g := range gates {
				total++
				f.stepStart(fmt.Sprintf("%s ...", g.name))

				out, err := g.fn()
				if err != nil {
					failed++
					f.stepFail(g.name)
					if out != "" {
						for _, line := range strings.Split(out, "\n") {
							if len(line) > 120 {
								line = line[:120] + "..."
							}
							f.stepInfo("  " + line)
						}
					}
					fmt.Printf("  %s\n\n", f.term.Dim("└─── FAILED"))
				} else {
					passed++
					f.stepOK(g.name)
					fmt.Printf("  %s\n\n", f.term.Dim("└─── pass"))
				}
			}

			// Summary
			f.divider()
			fmt.Printf("  %s ", f.term.Bold("Result:"))
			if failed == 0 {
				fmt.Printf("%s %d/%d gates passed\n", f.term.Good("ALL PASSED"), passed, total)
			} else {
				fmt.Printf("%s %d/%d gates passed, %d failed\n", f.term.Bad("FAILED"), passed, total, failed)
				fmt.Println()
				fmt.Println(f.term.Bad("  Fix all failures before committing."))
			}
			fmt.Println()

			if f.aiMode {
				result := map[string]interface{}{
					"action":  "validate",
					"passed":  passed,
					"failed":  failed,
					"total":   total,
					"success": failed == 0,
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			if failed > 0 {
				return fmt.Errorf("%d gate(s) failed", failed)
			}
			return nil
		},
	}


	cmd.Flags().StringVar(&host, "host", "", "NixOS host for nix eval (e.g. prague)")
	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW COMMIT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowCommit(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "commit [description]",
		Short: "Commit staged changes with conventional message",
		Long: `Stage and commit changes with a conventional commit message.

Auto-detects commit type from branch name:
  feature/*  → feat
  bugfix/*   → fix
  module/*   → module
  security/* → security
  docs/*     → docs

In AI mode, description must be provided as argument.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Commit")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}
			if branch == "main" {
				return fmt.Errorf("cannot commit to main branch directly — start a workflow first: ivali flow start")
			}

			// Auto-detect type from branch name
			commitType := "feat"
			switch {
			case strings.HasPrefix(branch, "bugfix/"):
				commitType = "fix"
			case strings.HasPrefix(branch, "module/"):
				commitType = "module"
			case strings.HasPrefix(branch, "security/"):
				commitType = "security"
			case strings.HasPrefix(branch, "architecture/"):
				commitType = "arch"
			case strings.HasPrefix(branch, "docs/"):
				commitType = "docs"
			}

			// Get description
			description := ""
			if len(args) > 0 {
				description = args[0]
			} else {
				fmt.Println(f.term.Dim("  Describe your changes:"))
				description = f.prompt("  Description:")
				if description == "" {
					return fmt.Errorf("description required")
				}
			}

			commitMsg := fmt.Sprintf("%s: %s", commitType, description)

			// Show changes
			f.stepStart("Changes to commit")
			if out, err := gitRun(f.repoDir, "git", "status", "--short"); err == nil {
				changes := strings.TrimSpace(out)
				if changes == "" {
					f.stepInfo("No changes to commit")
					f.stepFailed()
					return nil
				}
				for _, line := range strings.Split(changes, "\n") {
					f.stepInfo(line)
				}
			}
			f.stepDone()

			// Show commit details
			f.stepStart("Commit details")
			f.stepInfo(fmt.Sprintf("Branch:  %s", f.term.Code(branch)))
			f.stepInfo(fmt.Sprintf("Message: %s", f.term.Code(commitMsg)))
			f.stepDone()

			if !f.confirm("  Commit these changes?") {
				f.stepInfo("Cancelled")
				return nil
			}

			// Stage
			f.stepStart("Staging changes")
			if out, err := gitRun(f.repoDir, "git", "add", "-A"); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to stage: %s", out)
			}
			f.stepOK("Changes staged")
			f.stepDone()

			// Commit
			f.stepStart("Committing")
			if out, err := gitCommit(f.repoDir, commitMsg); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to commit: %s", out)
			}
			f.stepOK("Changes committed")
			f.stepDone()

			// Show diff
			f.stepStart("Files changed")
			if out, err := gitRun(f.repoDir, "git", "diff", "--stat", "HEAD~1"); err == nil {
				for _, line := range strings.Split(out, "\n") {
					f.stepInfo(line)
				}
			}
			f.stepDone()

			f.nextHint("ivali flow push")

			if f.aiMode {
				result := map[string]string{
					"action":  "commit",
					"type":    commitType,
					"message": commitMsg,
					"branch":  branch,
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}


	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW PUSH
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowPush(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "push",
		Short: "Push branch to GitLab",
		Long: `Push the current feature branch to GitLab.

Verifies working tree is clean and commits exist before pushing.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Push")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}
			if branch == "main" {
				return fmt.Errorf("cannot push to main branch directly")
			}

			f.stepStart("Branch info")
			f.stepInfo(fmt.Sprintf("Branch: %s", f.term.Code(branch)))
			f.stepDone()

			// Check clean tree
			f.stepStart("Checking for uncommitted changes")
			if out, err := gitRun(f.repoDir, "git", "status", "--porcelain"); err == nil && len(out) > 0 {
				f.stepInfo("You have uncommitted changes — run: ivali flow commit")
				f.stepFailed()
				return nil
			}
			f.stepOK("Working tree clean")
			f.stepDone()

			// Check unpushed commits
			f.stepStart("Checking for unpushed commits")
			commits, hasCommits := gitUnpushed(f.repoDir, branch)
			if !hasCommits {
				f.stepInfo("No commits to push")
				f.stepDone()
				return nil
			}
			for _, line := range strings.Split(commits, "\n") {
				f.stepInfo("  " + line)
			}
			f.stepDone()

			if !f.confirm("  Push to GitLab?") {
				f.stepInfo("Cancelled")
				return nil
			}

			// Push
			f.stepStart("Pushing to GitLab")
			if out, err := gitRun(f.repoDir, "git", "push", "origin", branch); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to push: %s", out)
			}
			f.stepOK("Pushed to GitLab")
			f.stepDone()

			f.nextHint("ivali flow mr")

			if f.aiMode {
				result := map[string]string{
					"action": "push",
					"branch": branch,
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}


	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW MR
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowMR(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "mr [title]",
		Short: "Create a GitLab merge request",
		Long: `Create a GitLab merge request for the current branch.

Loads the appropriate MR template and creates the MR via glab.
In AI mode, title must be provided as argument.`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Merge Request")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}
			if branch == "main" {
				return fmt.Errorf("cannot create MR from main branch")
			}

			// Check all pushed (compare against this branch's own remote, not main)
			f.stepStart("Checking for unpushed commits")
			_, hasCommits := gitUnpushed(f.repoDir, branch)
			if hasCommits {
				f.stepInfo("Push first: ivali flow push")
				f.stepFailed()
				return nil
			}
			f.stepOK("All commits pushed")
			f.stepDone()

			// Get title
			var title string
			if len(args) > 0 {
				title = args[0]
			} else {
				f.stepStart("Getting title from last commit")
				if out, err := gitRun(f.repoDir, "git", "log", "-1", "--pretty=%s"); err == nil {
					title = out
				}
				if title == "" {
					title = fmt.Sprintf("Changes from %s", branch)
				}
				f.stepOK(title)
				f.stepDone()

				// Custom title prompt (skip in AI mode — use commit message)
				if !aiMode {
					f.stepStart("MR title")
					if f.confirm("  Use custom title?") {
						fmt.Print("  Title: ")
						title = f.prompt("Title:")
					}
					f.stepDone()
				}
			}

			// Load template
			f.stepStart("Loading MR template")
			templatePath := filepath.Join(f.repoDir, ".gitlab", "merge_request_templates", "default.md")
			mrDesc := title
			if data, err := os.ReadFile(templatePath); err == nil {
				mrDesc = string(data)
				mrDesc = strings.ReplaceAll(mrDesc, "<!-- Brief description of changes -->", title)
			}
			f.stepOK("Template loaded")
			f.stepDone()

			// Summary
			f.stepStart("Summary")
			f.stepInfo(fmt.Sprintf("Source: %s", f.term.Code(branch)))
			f.stepInfo(fmt.Sprintf("Target: %s", f.term.Code("main")))
			f.stepInfo(fmt.Sprintf("Title:  %s", f.term.Code(title)))
			f.stepDone()

			if !f.confirm("  Create merge request?") {
				f.stepInfo("Cancelled")
				return nil
			}

			// Create MR
			f.stepStart("Creating merge request")
			mrCmd := exec.Command("glab", "mr", "create",
				"--source-branch", branch,
				"--target-branch", "main",
				"--title", title,
				"--description", mrDesc,
				"--remove-source-branch",
			)
			mrCmd.Dir = f.repoDir
			mrOut, err := mrCmd.CombinedOutput()
			if err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", string(mrOut)))
				f.stepFailed()
				return fmt.Errorf("failed to create MR: %s", string(mrOut))
			}
			mrURL := strings.TrimSpace(string(mrOut))
			f.stepOK(mrURL)
			f.stepDone()

			f.nextHint("ivali flow pipeline  (monitor CI)")

			if f.aiMode {
				result := map[string]string{
					"action": "mr",
					"title":  title,
					"url":    mrURL,
					"branch": branch,
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}


	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW PIPELINE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowPipeline(a *app.App) *cobra.Command {
	var watch bool
	var pollInterval int

	cmd := &cobra.Command{
		Use:   "pipeline [mr-iid]",
		Short: "Check or monitor GitLab CI pipeline status",
		Long: `Check the CI pipeline status for the current branch's MR.

With --watch, polls until the pipeline completes.
In AI mode, outputs JSON with the final status.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Pipeline")

			mrIID := ""
			if len(args) > 0 {
				mrIID = args[0]
			} else {
				branch, err := gitBranch(f.repoDir)
				if err != nil {
					return err
				}
				f.stepStart(fmt.Sprintf("Looking up MR for branch %s", f.term.Code(branch)))
				out, err := gitRun(f.repoDir, "glab", "mr", "list",
					"--source-branch", branch,
					"--output", "json",
				)
				if err != nil {
					f.stepFail(fmt.Sprintf("Failed: %s", out))
					f.stepFailed()
					return fmt.Errorf("failed to list MRs: %s", out)
				}
				var mrs []struct {
					IID int `json:"iid"`
				}
				if err := json.Unmarshal([]byte(out), &mrs); err == nil && len(mrs) > 0 {
					mrIID = fmt.Sprintf("%d", mrs[0].IID)
				}
				if mrIID == "" {
					f.stepInfo("No open MR found — create one with: ivali flow mr")
					f.stepDone()
					return nil
				}
				f.stepOK(fmt.Sprintf("Found MR #%s", mrIID))
				f.stepDone()
			}

			poll := func() (string, bool, error) {
				out, err := gitRun(f.repoDir, "glab", "api",
					fmt.Sprintf("projects/:id/merge_requests/%s/pipeline", mrIID))
				if err != nil {
					return "", false, fmt.Errorf("failed to get pipeline status: %s", out)
				}
				var pipeline struct {
					Status string `json:"status"`
				}
				if err := json.Unmarshal([]byte(out), &pipeline); err == nil {
					switch pipeline.Status {
					case "success":
						return "passed", true, nil
					case "failed":
						return "failed", true, nil
					case "canceled", "skipped":
						return pipeline.Status, true, nil
					case "running", "pending", "created":
						return pipeline.Status, false, nil
					default:
						return pipeline.Status, false, nil
					}
				}
				return out, false, nil
			}

			if watch {
				f.stepStart("Polling pipeline (Ctrl+C to stop)")
				f.stepDone()
				for {
					status, done, err := poll()
					if err != nil {
						return err
					}
					ts := time.Now().Format("15:04:05")
					if done {
						if status == "passed" {
							fmt.Printf("  [%s] %s %s\n", f.term.Dim(ts), f.term.Good(status), f.term.Dim("— pipeline complete"))
						} else {
							fmt.Printf("  [%s] %s %s\n", f.term.Dim(ts), f.term.Bad(status), f.term.Dim("— pipeline complete"))
						}
						fmt.Println()
						return nil
					}
					fmt.Printf("  [%s] %s %s\n", f.term.Dim(ts), status, f.term.Dim("— waiting..."))
					time.Sleep(time.Duration(pollInterval) * time.Second)
				}
			}

			// Single check
			status, _, err := poll()
			if err != nil {
				return err
			}

			f.stepStart("Pipeline Status")
			f.stepInfo(fmt.Sprintf("MR:     %s", f.term.Code("#"+mrIID)))
			f.stepInfo(fmt.Sprintf("Status: %s", f.term.Code(status)))
			f.stepDone()

			if status == "passed" {
				fmt.Println(f.term.Good("  CI passed — safe to merge"))
			} else if status == "failed" {
				fmt.Println(f.term.Bad("  CI failed — fix before merging"))
			} else {
				fmt.Println(f.term.Dim("  Pipeline still running — check again later"))
			}
			fmt.Println()

			if f.aiMode {
				result := map[string]interface{}{
					"action":  "pipeline",
					"mr_iid":  mrIID,
					"status":  status,
					"success": status == "passed",
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}


	cmd.Flags().BoolVarP(&watch, "watch", "w", false, "Poll until pipeline completes")
	cmd.Flags().IntVarP(&pollInterval, "interval", "i", 15, "Poll interval in seconds")
	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW MERGE — gates on CI
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowMerge(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "merge",
		Short: "Merge MR into main (gates on CI)",
		Long: `Merge the merge request for the current branch into main.

Checks that the CI pipeline has passed before merging. If CI is not
passed, the merge is blocked with guidance on how to fix.

In AI mode, automatically polls CI until it passes before merging.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Merge")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}
			if branch == "main" {
				return fmt.Errorf("cannot merge from main branch")
			}

			f.stepStart("Branch info")
			f.stepInfo(fmt.Sprintf("Branch: %s", f.term.Code(branch)))
			f.stepDone()

			// Find MR
			f.stepStart("Finding merge request")
			listOut, err := gitRun(f.repoDir, "glab", "mr", "list",
				"--source-branch", branch,
				"--output", "json",
			)
			if err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", listOut))
				f.stepFailed()
				return fmt.Errorf("failed to list MRs: %s", listOut)
			}

			var mrs []struct {
				IID      int    `json:"iid"`
				Title    string `json:"title"`
				Pipeline *struct {
					Status string `json:"status"`
				} `json:"head_pipeline"`
			}
			mrIID := ""
			var mrPipeline *struct {
				Status string `json:"status"`
			}

			if err := json.Unmarshal([]byte(listOut), &mrs); err == nil && len(mrs) > 0 {
				mrIID = fmt.Sprintf("%d", mrs[0].IID)
				mrPipeline = mrs[0].Pipeline
			}

			if mrIID == "" {
				f.stepInfo("No open MR found — create one with: ivali flow mr")
				f.stepFailed()
				return nil
			}
			f.stepOK(fmt.Sprintf("Found MR #%s", mrIID))
			f.stepDone()

			// CI gate
			f.stepStart("Checking CI pipeline status")
			ciPassed := false
			if mrPipeline != nil {
				switch mrPipeline.Status {
				case "success":
					ciPassed = true
					f.stepOK("CI pipeline passed")
				case "failed":
					f.stepFail("CI pipeline failed")
					f.stepInfo("Fix CI failures before merging.")
					f.stepInfo("Run: ivali flow pipeline --watch")
					f.stepFailed()
					return nil
				default:
					f.stepInfo(fmt.Sprintf("CI pipeline status: %s", f.term.Code(mrPipeline.Status)))
					f.stepInfo("Wait for CI to pass.")

					// In AI mode, poll until CI passes
					if f.aiMode {
						f.stepInfo("AI mode: polling CI until it passes...")
						for i := 0; i < 120; i++ { // max 30 min
							time.Sleep(15 * time.Second)
							pipelineOut, err := gitRun(f.repoDir, "glab", "api",
								fmt.Sprintf("projects/:id/merge_requests/%s/pipeline", mrIID))
							if err != nil {
								continue
							}
							var p struct {
								Status string `json:"status"`
							}
							if err := json.Unmarshal([]byte(pipelineOut), &p); err == nil {
								if p.Status == "success" {
									ciPassed = true
									f.stepOK("CI pipeline passed (polled)")
									break
								}
								if p.Status == "failed" {
									f.stepFail("CI pipeline failed")
									f.stepFailed()
									return fmt.Errorf("CI pipeline failed")
								}
								f.stepInfo(fmt.Sprintf("  CI status: %s — waiting...", p.Status))
							}
						}
					} else {
						f.stepFailed()
						f.stepInfo("Run: ivali flow merge  (after CI passes)")
						return nil
					}
				}
			} else {
				// No pipeline exists yet. In AI mode, poll briefly to wait for it to appear.
				if f.aiMode {
					f.stepInfo("No pipeline found yet — waiting for CI to start...")
					for i := 0; i < 5; i++ { // ~75 seconds
						time.Sleep(15 * time.Second)
						pipelineOut, err := gitRun(f.repoDir, "glab", "api",
							fmt.Sprintf("projects/:id/merge_requests/%s/pipeline", mrIID))
						if err != nil {
							continue
						}
						var p struct {
							Status string `json:"status"`
						}
						if err := json.Unmarshal([]byte(pipelineOut), &p); err == nil {
							mrPipeline = &struct {
								Status string `json:"status"`
							}{Status: p.Status}
							f.stepInfo(fmt.Sprintf("  CI status: %s", p.Status))
							break
						}
					}
				}

				if mrPipeline == nil {
					f.stepFail("No CI pipeline found")
					f.stepInfo("CI may still be starting. Wait a moment and try again.")
					f.stepInfo("Run: ivali flow pipeline --watch")
					f.stepFailed()
					return fmt.Errorf("no CI pipeline found for MR #%s", mrIID)
				}

				// Pipeline appeared — fall through to status check below
				switch mrPipeline.Status {
				case "success":
					ciPassed = true
					f.stepOK("CI pipeline passed")
				case "failed":
					f.stepFail("CI pipeline failed")
					f.stepInfo("Fix CI failures before merging.")
					f.stepInfo("Run: ivali flow pipeline --watch")
					f.stepFailed()
					return fmt.Errorf("CI pipeline failed")
				default:
					f.stepInfo(fmt.Sprintf("CI pipeline status: %s", f.term.Code(mrPipeline.Status)))
					f.stepInfo("Wait for CI to pass.")
					f.stepFailed()
					return fmt.Errorf("CI pipeline not yet passed (status: %s)", mrPipeline.Status)
				}
			}

			if !ciPassed {
				f.stepInfo("CI pipeline has not passed")
				f.stepFailed()
				return fmt.Errorf("CI pipeline has not passed")
			}
			f.stepDone()

			// Show MR
			f.stepStart("MR details")
			_, _ = gitRun(f.repoDir, "glab", "mr", "view", mrIID)
			f.stepDone()

			if !f.confirm("  Merge this MR?") {
				f.stepInfo("Cancelled")
				return nil
			}

			// Merge
			f.stepStart("Merging MR")
			mergeOut, err := gitRun(f.repoDir, "glab", "mr", "merge", mrIID,
				"--yes", "--remove-source-branch")
			if err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", mergeOut))
				f.stepFailed()
				return fmt.Errorf("failed to merge MR: %s", mergeOut)
			}
			f.stepOK("MR merged successfully")
			f.stepDone()

			// Switch to main
			f.stepStart("Switching to main")
			if out, err := gitRun(f.repoDir, "git", "checkout", "main"); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to switch to main: %s", out)
			}
			f.stepOK("On main")
			f.stepDone()

			// Pull
			f.stepStart("Pulling latest changes")
			if out, err := gitRun(f.repoDir, "git", "pull", "origin", "main"); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to pull: %s", out)
			}
			f.stepOK("Latest changes pulled")
			f.stepDone()

			f.nextHint("ivali flow deploy")

			if f.aiMode {
				result := map[string]string{
					"action": "merge",
					"mr":     mrIID,
					"branch": branch,
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}


	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW DEPLOY — uses operations engine
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowDeploy(a *app.App) *cobra.Command {
	var dryRun bool
	var skipChecks bool
	var host string

	cmd := &cobra.Command{
		Use:   "deploy [commit]",
		Short: "Deploy after merge (runs rebuild.sh with full validation)",
		Long: `Deploy after your MR has been merged to main.

Runs the rebuild script which validates everything before activating:
  1. git fetch + rebase
  2. Validate hardware UUIDs
  3. Check Go vendor hashes
  4. Nix evaluation gates
  5. Build & activate (nixos-rebuild switch)

The repo must have a clean commit on main. The rebuild script
ensures all verification gates pass before touching the system.

Flags:
  --dry-run       Show what would be deployed without doing it
  --skip-checks   Skip validation gates (emergency only)`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Deploy")

			// Step 1: Clean tree
			f.stepStart("Step 1: Checking for uncommitted changes")
			if out, err := gitRun(f.repoDir, "git", "status", "--porcelain"); err == nil && len(out) > 0 {
				f.stepInfo("You have uncommitted changes — commit or stash first")
				f.stepFailed()
				return nil
			}
			f.stepOK("Working tree clean")
			f.stepDone()

			// Step 2: Branch
			f.stepStart("Step 2: Checking branch")
			branch, _ := gitBranch(f.repoDir)
			if branch != "main" {
				f.stepInfo("Switching to main...")
				_, _ = gitRun(f.repoDir, "git", "checkout", "main")
			}
			f.stepOK("On main")
			f.stepDone()

			// Step 3: Pull
			f.stepStart("Step 3: Pulling latest changes")
			if out, err := gitRun(f.repoDir, "git", "pull", "origin", "main"); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to pull: %s", out)
			}
			f.stepOK("Latest changes pulled")
			f.stepDone()

			// Step 4: Show changes
			f.stepStart("Step 4: Changes to deploy")
			if out, err := gitRun(f.repoDir, "git", "log", "--oneline", "-10"); err == nil {
				for _, line := range strings.Split(out, "\n") {
					f.stepInfo(line)
				}
			}
			f.stepDone()

			// Dry run
			if dryRun {
				f.stepStart("Step 5: Dry run mode")
				f.stepInfo("Would run: ./scripts/rebuild.sh")
				f.stepInfo("")
				f.stepInfo("  1. git fetch origin main")
				f.stepInfo("  2. git rebase origin/main")
				f.stepInfo("  3. Validate hardware UUIDs")
				f.stepInfo("  4. Check Go vendor hashes")
				f.stepInfo("  5. Nix evaluation gates")
				f.stepInfo("  6. Build & activate (nixos-rebuild switch)")
				f.stepInfo("")
				f.stepInfo(fmt.Sprintf("  To deploy for real: %s", f.term.Code("ivali flow deploy")))
				f.stepDone()
				return nil
			}

			// Confirm
			fmt.Println()
			f.stepStart("Deploy plan")
			f.stepInfo("This will run:")
			f.stepInfo("  1. git fetch origin main")
			f.stepInfo("  2. git rebase origin/main")
			f.stepInfo("  3. Validate hardware UUIDs")
			f.stepInfo("  4. Check Go vendor hashes")
			f.stepInfo("  5. Nix evaluation gates")
			f.stepInfo("  6. Build & activate (nixos-rebuild switch)")
			f.stepInfo("")
			f.stepInfo(fmt.Sprintf("  %s This may take 15-30 minutes", f.term.Warn("⚠")))
			f.stepDone()

			if !f.confirm("  Deploy now?") {
				f.stepInfo("Cancelled")
				return nil
			}

			// Step 6: Run rebuild
			fmt.Println()
			f.stepStart("Step 6: Running nixos-rebuild switch")
			f.stepInfo(fmt.Sprintf("  %s ./scripts/rebuild.sh", f.term.Dim("▶")))
			f.stepInfo("")

			var rebuildCmd *exec.Cmd
			if skipChecks {
				f.stepInfo("  Skipping validation gates (--skip-checks)")
				fallbackHost := host
				if fallbackHost == "" {
					fallbackHost = detectDefaultHost(f.repoDir)
				}
				rebuildCmd = exec.Command("sudo", "nixos-rebuild", "switch",
					"--flake", f.repoDir+"#"+fallbackHost)
			} else {
				rebuildCmd = exec.Command("./scripts/rebuild.sh")
			}
			rebuildCmd.Dir = f.repoDir
			rebuildCmd.Stdout = os.Stdout
			rebuildCmd.Stderr = os.Stderr

			if err := rebuildCmd.Run(); err != nil {
				f.stepInfo("")
				f.stepFail(fmt.Sprintf("%v", err))
				f.stepInfo("")
				f.stepInfo("Deploy failed. You can:")
				f.stepInfo("  1. Check logs: journalctl -xe")
				f.stepInfo("  2. Rollback: ivali flow rollback")
				f.stepInfo("  3. Try again: ivali flow deploy")
				f.stepFailed()
				return nil
			}

			f.stepInfo("")
			f.stepDone()

			// Summary
			fmt.Println()
			f.stepStart("Deployment Summary")
			f.stepInfo("")

			// Get current generation
			if out, err := gitRun(f.repoDir, "nixos-rebuild", "list-generations"); err == nil {
				gens := strings.Split(strings.TrimSpace(out), "\n")
				if len(gens) > 0 {
					f.stepInfo(fmt.Sprintf("  Current generation: %s", f.term.Code(gens[len(gens)-1])))
				}
			}

			f.stepInfo("")
			f.stepInfo("  ✓ System rebuilt successfully")
			f.stepInfo("  ✓ New generation activated")
			f.stepInfo("  ✓ Services restarted")
			f.stepInfo("")
			f.stepDone()

			if f.aiMode {
				result := map[string]interface{}{
					"action": "deploy",
					"status": "deployed",
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}


	cmd.Flags().BoolVarP(&dryRun, "dry-run", "d", false, "Show what would be deployed without doing it")
	cmd.Flags().BoolVar(&skipChecks, "skip-checks", false, "Skip validation gates (emergency only)")
	cmd.Flags().StringVar(&host, "host", "", "NixOS host for deploy (auto-detected if empty)")
	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW ROLLBACK
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowRollback(a *app.App) *cobra.Command {
	var generation int
	var listGens bool

	cmd := &cobra.Command{
		Use:   "rollback",
		Short: "Roll back to a previous NixOS generation",
		Long: `Activate a previous NixOS system generation.

Routes through the operations deployment engine.

Examples:
  ivali flow rollback             # Interactive: prompts for confirmation
  ivali flow rollback -g 42       # Roll back to generation 42
  ivali flow rollback --list      # List available generations`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Rollback")

			// List mode
			if listGens {
				f.stepStart("Available Generations")
				genSvc := operations.NewGenerationService()
				gens, err := genSvc.List(cmd.Context())
				if err != nil {
					f.stepFail(fmt.Sprintf("Failed: %v", err))
				} else {
					for _, g := range gens {
						marker := "  "
						if g.Active {
							marker = f.term.Bold("►")
						}
						f.stepInfo(fmt.Sprintf("%s %s  %s", marker,
							f.term.Code(fmt.Sprintf("%-4d", g.Number)),
							f.term.Dim(g.Date.Format("2006-01-02 15:04:05"))))
					}
				}
				f.stepDone()
				return nil
			}

			// Rollback
			var target string
			if generation > 0 {
				target = fmt.Sprintf("generation %d", generation)
			} else {
				target = "previous generation"
			}

			f.stepStart(fmt.Sprintf("Roll back to %s?", target))
			if !f.confirm("  Confirm rollback?") {
				f.stepInfo("Cancelled")
				f.stepDone()
				return nil
			}

			f.stepStart("Rolling back")
			audit := operations.NewAuditLogger()
			deploy := operations.NewDeploymentService(f.repoDir, audit)

			startTime := time.Now()
			result, err := deploy.Rollback(context.Background(), operations.RollbackOpts{
				Generation: generation,
				Actor:      "ivali-cli",
				Reason:     "manual rollback via flow",
			})
			elapsed := time.Since(startTime).Round(time.Second)

			if err != nil {
				f.stepFail(fmt.Sprintf("Rollback failed: %v", err))
				f.stepFailed()
				return nil
			}

			f.stepInfo("")
			f.stepDone()

			// Summary
			f.stepStart("Rollback Summary")
			f.stepInfo("")
			if result.Success {
				f.stepInfo(fmt.Sprintf("  Status:     %s", f.term.Good("success")))
			} else {
				f.stepInfo(fmt.Sprintf("  Status:     %s", f.term.Bad("failed")))
			}
			f.stepInfo(fmt.Sprintf("  Generation: %s → %s",
				f.term.Code(fmt.Sprintf("%d", result.FromGen)),
				f.term.Code(fmt.Sprintf("%d", result.ToGen))))
			f.stepInfo(fmt.Sprintf("  Health:     %s", f.term.Code(fmt.Sprintf("%v", result.HealthPassed))))
			f.stepInfo(fmt.Sprintf("  Duration:   %s", f.term.Code(elapsed.String())))
			if result.Error != "" {
				f.stepInfo(fmt.Sprintf("  Error:      %s", f.term.Code(result.Error)))
			}
			f.stepInfo("")
			f.stepDone()

			if f.aiMode {
				resultJSON := map[string]interface{}{
					"action":   "rollback",
					"success":  result.Success,
					"from_gen": result.FromGen,
					"to_gen":   result.ToGen,
					"health":   result.HealthPassed,
					"duration": elapsed.String(),
				}
				data, _ := json.MarshalIndent(resultJSON, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}


	cmd.Flags().IntVarP(&generation, "generation", "g", 0, "Target generation (0 = previous)")
	cmd.Flags().BoolVar(&listGens, "list", false, "List available generations")
	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW QUICK — single-shot commit → push → MR (AI-friendly)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowQuick(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "quick [description]",
		Short: "Single-shot: commit → push → create MR (AI-friendly)",
		Long: `Run the full development pipeline in one command.

  ivali flow quick "add nftables firewall module"

This will:
  1. Validate all gates (ivali flow validate)
  2. Stage and commit changes
  3. Push branch to GitLab
  4. Create merge request
  5. Show CI pipeline status

Designed for agentic workflows: the AI makes file changes, then calls
'ivali flow quick "description"' to commit and push everything.

Examples:
  ivali flow quick "add firewall rules"            # Interactive
  ivali flow quick "add firewall rules"            # Non-interactive (auto when stdin is not a terminal)`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			description := args[0]

			f.header("Flow Quick")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}
			if branch == "main" {
				return fmt.Errorf("cannot run quick on main — start a workflow first: ivali flow start")
			}

			// ── Step 1: Validate ────────────────────────────────────────
			f.stepStart("Step 1/5: Running validation gates")
			f.stepInfo("")

			type gateEntry struct {
				name string
				fn   func() (string, error)
			}
			gates := []gateEntry{
				{"nix fmt", func() (string, error) { return gitRun(f.repoDir, "nix", "fmt", "--", "--check", ".") }},
				{"shellcheck", func() (string, error) {
					out, err := gitRun(f.repoDir, "shellcheck", "--severity=warning")
					if err != nil && strings.Contains(out, "No such file") {
						return "", nil
					}
					return out, err
				}},
				{"go build", func() (string, error) { return gitRun(f.repoDir, "go", "build", "./...") }},
				{"go vet", func() (string, error) { return gitRun(f.repoDir, "go", "vet", "./...") }},
				{"go test -race", func() (string, error) { return gitRun(f.repoDir, "go", "test", "-race", "-count=1", "./...") }},
				{"nix flake check", func() (string, error) { return gitRun(f.repoDir, "nix", "flake", "check", "--no-build") }},
			}

			gateFailed := false
			for _, g := range gates {
				out, err := g.fn()
				if err != nil {
					f.stepFail(g.name)
					if out != "" {
						for _, line := range strings.Split(out, "\n") {
							if len(line) > 120 {
								line = line[:120] + "..."
							}
							f.stepInfo("  " + line)
						}
					}
					gateFailed = true
				} else {
					f.stepOK(g.name)
				}
			}

			if gateFailed {
				fmt.Println()
				f.stepInfo(f.term.Bad("  Validation failed — fix errors before pushing"))
				f.stepFailed()
				return fmt.Errorf("validation failed")
			}
			f.stepOK("All gates passed")
			f.stepDone()

			// ── Step 2: Commit ──────────────────────────────────────────
			f.stepStart("Step 2/5: Committing changes")

			// Auto-detect commit type from branch
			commitType := "feat"
			switch {
			case strings.HasPrefix(branch, "bugfix/"):
				commitType = "fix"
			case strings.HasPrefix(branch, "module/"):
				commitType = "module"
			case strings.HasPrefix(branch, "security/"):
				commitType = "security"
			case strings.HasPrefix(branch, "architecture/"):
				commitType = "arch"
			case strings.HasPrefix(branch, "docs/"):
				commitType = "docs"
			}
			commitMsg := fmt.Sprintf("%s: %s", commitType, description)

			// Stage
			if out, err := gitRun(f.repoDir, "git", "add", "-A"); err != nil {
				f.stepFail(fmt.Sprintf("Failed to stage: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to stage: %s", out)
			}
			f.stepOK("Changes staged")

			// Check if anything to commit
			if _, err := gitRun(f.repoDir, "git", "diff", "--cached", "--quiet"); err == nil {
				f.stepInfo("No changes to commit (working tree clean)")
				f.stepDone()
				f.stepInfo("")
				f.stepInfo("Nothing to commit — all changes may already be committed.")
				return nil
			}

			// Commit
			if out, err := gitCommit(f.repoDir, commitMsg); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to commit: %s", out)
			}
			f.stepOK(fmt.Sprintf("Committed: %s", f.term.Code(commitMsg)))
			f.stepDone()

			// ── Step 3: Push ────────────────────────────────────────────
			f.stepStart("Step 3/5: Pushing to GitLab")
			if out, err := gitRun(f.repoDir, "git", "push", "origin", branch); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to push: %s", out)
			}
			f.stepOK(fmt.Sprintf("Pushed to %s", f.term.Code(branch)))
			f.stepDone()

			// ── Step 4: Create MR ──────────────────────────────────────
			f.stepStart("Step 4/5: Creating merge request")

			// Load template
			templatePath := filepath.Join(f.repoDir, ".gitlab", "merge_request_templates", "default.md")
			mrDesc := description
			if data, err := os.ReadFile(templatePath); err == nil {
				mrDesc = string(data)
				mrDesc = strings.ReplaceAll(mrDesc, "<!-- Brief description of changes -->", description)
			}

			mrCmd := exec.Command("glab", "mr", "create",
				"--source-branch", branch,
				"--target-branch", "main",
				"--title", description,
				"--description", mrDesc,
				"--remove-source-branch",
			)
			mrCmd.Dir = f.repoDir
			mrOut, err := mrCmd.CombinedOutput()
			if err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", string(mrOut)))
				f.stepFailed()
				return fmt.Errorf("failed to create MR: %s", string(mrOut))
			}
			mrURL := strings.TrimSpace(string(mrOut))
			f.stepOK(mrURL)
			f.stepDone()

			// ── Step 5: Pipeline status ────────────────────────────────
			f.stepStart("Step 5/5: CI pipeline status")

			// Find the MR IID
			listOut, listErr := gitRun(f.repoDir, "glab", "mr", "list",
				"--source-branch", branch, "--output", "json")
			if listErr == nil {
				var mrs []struct {
					IID      int `json:"iid"`
					Pipeline *struct {
						Status string `json:"status"`
					} `json:"head_pipeline"`
				}
				if err := json.Unmarshal([]byte(listOut), &mrs); err == nil && len(mrs) > 0 {
					pipeline := mrs[0].Pipeline
					if pipeline != nil {
						f.stepInfo(fmt.Sprintf("Pipeline: %s", f.term.Code(pipeline.Status)))
					} else {
						f.stepInfo("Pipeline: starting...")
					}
				}
			}
			f.stepDone()

			// Final summary
			fmt.Println()
			f.divider()
			fmt.Println(f.term.Bold("  Flow Quick — Complete"))
			fmt.Println()
			f.stepInfo(fmt.Sprintf("  Branch: %s", f.term.Code(branch)))
			f.stepInfo(fmt.Sprintf("  Commit: %s", f.term.Code(commitMsg)))
			f.stepInfo(fmt.Sprintf("  MR:     %s", f.term.Code(mrURL)))
			f.stepInfo("")
			f.stepInfo(fmt.Sprintf("  Monitor CI: %s", f.term.Code("ivali flow pipeline --watch")))
			f.stepInfo(fmt.Sprintf("  Merge:      %s", f.term.Code("ivali flow merge")))
			fmt.Println()

			if f.aiMode {
				result := map[string]string{
					"action": "quick",
					"branch": branch,
					"commit": commitMsg,
					"mr":     mrURL,
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}


	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW RUN — full pipeline in one command
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowRun(a *app.App) *cobra.Command {
	var implement bool

	cmd := &cobra.Command{
		Use:   "run [type] [description]",
		Short: "Full pipeline: start → implement → validate → commit → push → MR → merge",
		Long: `Run the entire development workflow in a single command.

Chains every step from issue creation to merge:
  1. Create GitLab issue + feature branch
  2. AI implementation (opencode or freebuff)
  3. Validate all gates (nix fmt, go build, go test, etc.)
  4. Stage and commit
  5. Push to GitLab
  6. Create merge request
  7. Wait for CI pipeline + merge
  8. Switch to main + pull

Then run 'ivali deploy' to activate the new generation.

Examples:
  ivali flow run feature "add notion enhanced to panel"
  ivali flow run bugfix "fix zsh completions"
  ivali flow run feature "add firewall module"             # interactive
  ivali flow run feature "desc" --no-implement              # skip AI`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Run")

			if aiMode {
				implement = true
			}

			// ── Step 0: Gather inputs ──────────────────────────────────
			changeType := ""
			if len(args) > 0 {
				changeType = args[0]
			} else {
				fmt.Println("  What type of change is this?")
				fmt.Println()
				fmt.Println("    1) feature       New feature or enhancement")
				fmt.Println("    2) bugfix        Bug fix")
				fmt.Println("    3) module        New NixOS/Home Manager module")
				fmt.Println("    4) security      Security hardening")
				fmt.Println("    5) architecture  Architecture changes")
				fmt.Println("    6) docs          Documentation")
				fmt.Println()
				reader := bufio.NewReader(os.Stdin)
				fmt.Printf("  Select (1-6): ")
				choice, _ := reader.ReadString('\n')
				choice = strings.TrimSpace(choice)
				switch choice {
				case "1":
					changeType = "feature"
				case "2":
					changeType = "bugfix"
				case "3":
					changeType = "module"
				case "4":
					changeType = "security"
				case "5":
					changeType = "architecture"
				case "6":
					changeType = "docs"
				default:
					return fmt.Errorf("invalid selection: %s", choice)
				}
			}

			validTypes := map[string]bool{
				"feature": true, "bugfix": true, "module": true,
				"security": true, "architecture": true, "docs": true,
			}
			if !validTypes[changeType] {
				return fmt.Errorf("invalid type: %s", changeType)
			}

			description := ""
			if len(args) > 1 {
				description = args[1]
			} else {
				fmt.Println()
				fmt.Println("  Describe what you want to do:")
				reader := bufio.NewReader(os.Stdin)
				fmt.Printf("  Description: ")
				description, _ = reader.ReadString('\n')
				description = strings.TrimSpace(description)
				if description == "" {
					return fmt.Errorf("description required")
				}
			}

			// Summary
			fmt.Println()
			fmt.Println(f.term.Dim("  ┌─────────────────────────────────────────────┐"))
			fmt.Println(f.term.Dim("  │  Summary:"))
			fmt.Printf("  │    Type:        %s\n", f.term.Code(changeType))
			fmt.Printf("  │    Description: %s\n", f.term.Code(description))
			fmt.Println(f.term.Dim("  └─────────────────────────────────────────────┘"))
			fmt.Println()

			if !f.confirm("  Continue?") {
				f.stepInfo("Cancelled")
				return nil
			}

			// ═══════════════════════════════════════════════════════════════
			// PHASE 1: Create issue + branch
			// ═══════════════════════════════════════════════════════════════
			f.stepStart("Step 1: Creating GitLab issue")

			templatePath := filepath.Join(f.repoDir, ".gitlab", "issue_templates", changeType+".md")
			issueBody := ""
			fmt.Printf("  │  %s Loading  %s template...\n", f.term.Dim("▶"), f.term.Code(changeType))
			if data, err := os.ReadFile(templatePath); err == nil {
				issueBody = string(data)
				issueBody = strings.ReplaceAll(issueBody, "<!-- What does this feature do? -->", description)
				issueBody = strings.ReplaceAll(issueBody, "<!-- What is the bug? -->", description)
				issueBody = strings.ReplaceAll(issueBody, "<!-- What capability does this module provide? -->", description)
				issueBody = strings.ReplaceAll(issueBody, "<!-- What is the security concern? -->", description)
				f.stepOK("Template loaded")
			} else {
				issueBody = fmt.Sprintf("## Description\n\n%s\n\n## Type\n\n%s", description, changeType)
				f.stepInfo("No template found — using default")
			}

			issueTitle := fmt.Sprintf("[%s] %s", changeType, description)
			fmt.Printf("  │  %s Creating issue...\n", f.term.Dim("▶"))
			issueCmd := exec.Command("glab", "issue", "create",
				"--title", issueTitle,
				"--description", issueBody,
				"--label", changeType,
			)
			issueCmd.Dir = f.repoDir
			issueOut, err := issueCmd.CombinedOutput()
			if err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", string(issueOut)))
				f.stepFailed()
				return fmt.Errorf("failed to create issue: %s", string(issueOut))
			}
			issueURL := extractGitLabURL(string(issueOut))
			issueNum := extractIssueNum(issueURL)
			f.stepOK(issueURL)
			f.stepDone()

			f.stepStart("Step 2: Creating branch")
			branchName := fmt.Sprintf("%s/%s", changeType, cleanBranchName(description))
			if len(branchName) > 60 {
				branchName = branchName[:60]
			}
			fmt.Printf("  │  %s git checkout -b %s\n", f.term.Dim("▶"), f.term.Code(branchName))
			if out, err := gitRun(f.repoDir, "git", "checkout", "-b", branchName); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to create branch: %s", out)
			}
			f.stepOK(fmt.Sprintf("Branch %s created", f.term.Code(branchName)))
			f.stepDone()

			// ═══════════════════════════════════════════════════════════════
			// PHASE 2: AI implementation
			// ═══════════════════════════════════════════════════════════════
			if implement {
				f.stepStart("Step 3: AI Implementation")
				f.stepInfo("")
				f.stepInfo("  The AI will now implement the changes.")
				f.stepInfo("  It will create/modify files, write tests, and update docs.")
				f.stepInfo("")

				prompt := buildImplementPrompt(f.repoDir, changeType, description, issueNum)
				fmt.Printf("  │  %s %s\n", f.term.Dim("Prompt:"), f.term.Code(prompt[:80]+"..."))
				f.stepInfo("")

				f.stepInfo("Calling AI tool...")
				tool, err := runAITool(f.repoDir, prompt)
				if err != nil {
					f.stepInfo(fmt.Sprintf("  %s %v", f.term.Warn("⚠"), err))
					f.stepInfo("  You can run the AI tool manually later")
				} else {
					f.stepOK(fmt.Sprintf("AI implementation complete (via %s)", tool))
				}
				f.stepDone()
			}

			// ═══════════════════════════════════════════════════════════════
			// PHASE 3: Validate
			// ═══════════════════════════════════════════════════════════════
			f.stepStart("Step 4: Validation gates")
			f.stepInfo("")

			type gateEntry struct {
				name string
				fn   func() (string, error)
			}
			gates := []gateEntry{
				{"nix fmt", func() (string, error) { return gitRun(f.repoDir, "nix", "fmt", "--", "--check", ".") }},
				{"shellcheck", func() (string, error) {
					out, err := gitRun(f.repoDir, "shellcheck", "--severity=warning")
					if err != nil && strings.Contains(out, "No such file") {
						return "", nil
					}
					return out, err
				}},
				{"go build", func() (string, error) { return gitRun(f.repoDir, "go", "build", "./...") }},
				{"go vet", func() (string, error) { return gitRun(f.repoDir, "go", "vet", "./...") }},
				{"go test -race", func() (string, error) { return gitRun(f.repoDir, "go", "test", "-race", "-count=1", "./...") }},
				{"nix flake check", func() (string, error) { return gitRun(f.repoDir, "nix", "flake", "check", "--no-build") }},
			}

			gateFailed := false
			for _, g := range gates {
				out, err := g.fn()
				if err != nil {
					f.stepFail(g.name)
					if out != "" {
						for _, line := range strings.Split(out, "\n") {
							if len(line) > 120 {
								line = line[:120] + "..."
							}
							f.stepInfo("  " + line)
						}
					}
					gateFailed = true
				} else {
					f.stepOK(g.name)
				}
			}

			if gateFailed {
				fmt.Println()
				f.stepInfo(f.term.Bad("  Validation failed — fix errors before pushing"))
				f.stepFailed()
				return fmt.Errorf("validation failed")
			}
			f.stepOK("All gates passed")
			f.stepDone()

			// ═══════════════════════════════════════════════════════════════
			// PHASE 4: Commit + Push + MR
			// ═══════════════════════════════════════════════════════════════
			f.stepStart("Step 5: Committing changes")

			// Auto-detect commit type from branch
			commitType := "feat"
			switch {
			case strings.HasPrefix(branchName, "bugfix/"):
				commitType = "fix"
			case strings.HasPrefix(branchName, "module/"):
				commitType = "module"
			case strings.HasPrefix(branchName, "security/"):
				commitType = "security"
			case strings.HasPrefix(branchName, "architecture/"):
				commitType = "arch"
			case strings.HasPrefix(branchName, "docs/"):
				commitType = "docs"
			}
			commitMsg := fmt.Sprintf("%s: %s", commitType, description)

			if out, err := gitRun(f.repoDir, "git", "add", "-A"); err != nil {
				f.stepFail(fmt.Sprintf("Failed to stage: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to stage: %s", out)
			}
			f.stepOK("Changes staged")

			if _, err := gitRun(f.repoDir, "git", "diff", "--cached", "--quiet"); err == nil {
				f.stepInfo("No changes to commit — all changes may already be committed.")
				f.stepDone()
			} else {
				if out, err := gitCommit(f.repoDir, commitMsg); err != nil {
					f.stepFail(fmt.Sprintf("Failed: %s", out))
					f.stepFailed()
					return fmt.Errorf("failed to commit: %s", out)
				}
				f.stepOK(fmt.Sprintf("Committed: %s", f.term.Code(commitMsg)))
				f.stepDone()
			}

			f.stepStart("Step 6: Pushing to GitLab")
			if out, err := gitRun(f.repoDir, "git", "push", "-u", "origin", branchName); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to push: %s", out)
			}
			f.stepOK(fmt.Sprintf("Pushed to %s", f.term.Code(branchName)))
			f.stepDone()

			f.stepStart("Step 7: Creating merge request")

			templatePath = filepath.Join(f.repoDir, ".gitlab", "merge_request_templates", "default.md")
			mrDesc := description
			if data, err := os.ReadFile(templatePath); err == nil {
				mrDesc = string(data)
				mrDesc = strings.ReplaceAll(mrDesc, "<!-- Brief description of changes -->", description)
			}

			mrCmd := exec.Command("glab", "mr", "create",
				"--source-branch", branchName,
				"--target-branch", "main",
				"--title", commitMsg,
				"--description", mrDesc,
				"--remove-source-branch",
			)
			mrCmd.Dir = f.repoDir
			mrOut, err := mrCmd.CombinedOutput()
			if err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", string(mrOut)))
				f.stepFailed()
				return fmt.Errorf("failed to create MR: %s", string(mrOut))
			}
			mrURL := strings.TrimSpace(string(mrOut))
			f.stepOK(mrURL)
			f.stepDone()

			// ═══════════════════════════════════════════════════════════════
			// PHASE 5: Wait for CI + Merge
			// ═══════════════════════════════════════════════════════════════
			f.stepStart("Step 8: Waiting for CI pipeline")

			// Find the MR IID
			listOut, listErr := gitRun(f.repoDir, "glab", "mr", "list",
				"--source-branch", branchName, "--output", "json")
			mrIID := ""
			if listErr == nil {
				var mrs []struct {
					IID      int `json:"iid"`
					Pipeline *struct {
						Status string `json:"status"`
					} `json:"head_pipeline"`
				}
				if err := json.Unmarshal([]byte(listOut), &mrs); err == nil && len(mrs) > 0 {
					mrIID = fmt.Sprintf("%d", mrs[0].IID)
				}
			}

			if mrIID == "" {
				f.stepInfo("Could not find MR IID — run: ivali flow merge")
				f.stepDone()
			} else {
				// Poll CI until it passes or fails
				ciPassed := false
				for i := 0; i < 120; i++ { // max 30 min
					time.Sleep(15 * time.Second)
					pipelineOut, err := gitRun(f.repoDir, "glab", "api",
						fmt.Sprintf("projects/:id/merge_requests/%s/pipeline", mrIID))
					if err != nil {
						continue
					}
					var p struct {
						Status string `json:"status"`
					}
					if err := json.Unmarshal([]byte(pipelineOut), &p); err == nil {
						if p.Status == "success" {
							ciPassed = true
							f.stepOK("CI pipeline passed")
							break
						}
						if p.Status == "failed" {
							f.stepFail("CI pipeline failed")
							f.stepInfo("Fix CI failures, then run: ivali flow merge")
							f.stepDone()
							// Fall through — don't block, let user decide
							goto pipelineDone
						}
						if i%4 == 0 {
							f.stepInfo(fmt.Sprintf("  CI status: %s — waiting...", p.Status))
						}
					}
				}

				if ciPassed {
					// Merge
					f.stepStart("Step 9: Merging MR")
					mergeOut, err := gitRun(f.repoDir, "glab", "mr", "merge", mrIID,
						"--yes", "--remove-source-branch")
					if err != nil {
						f.stepFail(fmt.Sprintf("Failed: %s", mergeOut))
						f.stepDone()
						f.stepInfo("Run: ivali flow merge  (after CI passes)")
					} else {
						f.stepOK("MR merged")
						f.stepDone()

						// Switch to main + pull
						f.stepStart("Switching to main")
						if out, err := gitRun(f.repoDir, "git", "checkout", "main"); err != nil {
							f.stepFail(fmt.Sprintf("Failed: %s", out))
						} else {
							f.stepOK("On main")
						}
						f.stepDone()

						f.stepStart("Pulling latest changes")
						if out, err := gitRun(f.repoDir, "git", "pull", "origin", "main"); err != nil {
							f.stepFail(fmt.Sprintf("Failed: %s", out))
						} else {
							f.stepOK("Latest changes pulled")
						}
						f.stepDone()
					}
				}
			pipelineDone:
				f.stepDone()
			}

			// ═══════════════════════════════════════════════════════════════
			// Summary
			// ═══════════════════════════════════════════════════════════════
			fmt.Println()
			f.divider()
			fmt.Println(f.term.Bold("  Flow Run — Complete"))
			fmt.Println()
			f.stepInfo(fmt.Sprintf("  Issue:   %s", f.term.Code(issueURL)))
			f.stepInfo(fmt.Sprintf("  Branch:  %s", f.term.Code(branchName)))
			f.stepInfo(fmt.Sprintf("  MR:      %s", f.term.Code(mrURL)))
			f.stepInfo("")
			f.stepInfo(fmt.Sprintf("  Next: %s", f.term.Code("ivali deploy")))
			fmt.Println()

			if f.aiMode {
				result := map[string]string{
					"action":      "run",
					"type":        changeType,
					"description": description,
					"issue":       issueURL,
					"issue_num":   issueNum,
					"branch":      branchName,
					"commit":      commitMsg,
					"mr":          mrURL,
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}


	cmd.Flags().BoolVar(&implement, "implement", true, "Call AI (opencode or freebuff) to write the code for this change (default true, use --implement=false to skip)")
	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW STATUS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func flowStatus(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "status",
		Short: "Show current workflow status",
		Long: `Show the status of the current development workflow.

Displays branch, uncommitted changes, unpushed commits, and the next
step in the workflow pipeline.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("Flow Status")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}

			f.stepStart("Current state")
			f.stepInfo(fmt.Sprintf("Branch: %s", f.term.Code(branch)))
			f.stepDone()

			if branch == "main" {
				fmt.Println(f.term.Dim("  Ready to start a new workflow"))
				fmt.Println()
				fmt.Println(f.term.Dim("  Run: ivali flow start"))
			} else {
				// Changes
				f.stepStart("Changes")
				if out, err := gitRun(f.repoDir, "git", "status", "--short"); err == nil {
					changes := strings.TrimSpace(out)
					if changes != "" {
						for _, line := range strings.Split(changes, "\n") {
							f.stepInfo(line)
						}
					} else {
						f.stepInfo("No changes")
					}
				}
				f.stepDone()

				// Commits ahead
				f.stepStart("Commits ahead of main")
				commits, hasCommits := gitUnpushed(f.repoDir, branch)
				if hasCommits {
					for _, line := range strings.Split(commits, "\n") {
						f.stepInfo(line)
					}
				} else {
					f.stepInfo("No commits yet")
				}
				f.stepDone()

				// Workflow steps
				f.stepStart("Workflow steps")
				f.stepInfo("  1. ivali flow validate     Run all verification gates")
				f.stepInfo("  2. ivali flow commit       Stage and commit changes")
				f.stepInfo("  3. ivali flow push         Push branch to GitLab")
				f.stepInfo("  4. ivali flow mr           Create merge request")
				f.stepInfo("  5. ivali flow pipeline     Monitor CI status")
				f.stepInfo("  6. ivali flow merge        Merge (gates on CI)")
				f.stepInfo("  7. ivali flow deploy       Deploy the new generation")
				f.stepInfo("")
				f.stepInfo(fmt.Sprintf("  Shortcut: %s (commit→push→MR in one step)", f.term.Code("ivali flow quick")))
				f.stepInfo(fmt.Sprintf("  Rollback: %s", f.term.Code("ivali flow rollback")))
				f.stepDone()
			}

			fmt.Println()
			return nil
		},
	}


	return cmd
}

// detectDefaultHost scans hosts/ for .nix host spec files and returns the first
// hostname found. Returns "prague" as a fallback if no host files exist.
func detectDefaultHost(repoDir string) string {
	hostsDir := filepath.Join(repoDir, "hosts")
	entries, err := os.ReadDir(hostsDir)
	if err != nil {
		return "prague"
	}

	skipFiles := map[string]bool{
		"hosts.nix":                  true,
		"hardware-configuration.nix": true,
		"default.nix":                true,
	}

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".nix") {
			continue
		}
		if skipFiles[entry.Name()] {
			continue
		}
		name := strings.TrimSuffix(entry.Name(), ".nix")
		return name
	}

	return "prague"
}
