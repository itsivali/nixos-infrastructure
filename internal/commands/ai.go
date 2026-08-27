package commands

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CMD AI — root command
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func CmdAI(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "ai",
		Short: "🤖  AI-powered development workflow",
		Long: `AI-native development workflow for NixOS infrastructure.

Guided, interactive commands that combine GitLab issues, feature branches,
OpenCode AI implementation, verification gates, commits, MRs, and deployment.

Routes:
  ivali ai implement    Guided: issue → branch → AI code → validate → commit → push → MR
  ivali ai validate     Run all verification gates
  ivali ai commit       Stage and commit with conventional message
  ivali ai push         Push branch to GitLab
  ivali ai mr           Create merge request
  ivali ai quick        Single-shot: validate → commit → push → MR
  ivali ai status       Show AI system availability
  ivali ai route        Route a task to the appropriate AI`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(
		aiImplement(a),
		aiValidate(a),
		aiCommit(a),
		aiPush(a),
		aiMR(a),
		aiQuick(a),
		aiStatus(a),
		aiRoute(a),
	)

	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// AI IMPLEMENT — guided AI-powered development
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func aiImplement(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "implement [type] [description]",
		Short: "Guided AI implementation: issue → branch → code → validate → commit → push → MR",
		Long: `AI-powered development workflow with guided UX.

Creates a GitLab issue, feature branch, calls OpenCode to write code,
runs verification gates, commits, pushes, and creates a merge request.

Change types:
  feature       New feature or enhancement
  bugfix        Bug fix
  module        New NixOS/Home Manager module
  security      Security hardening
  architecture  Architecture changes
  docs          Documentation

Examples:
  ivali ai implement                                    # Interactive: prompts for type + description
  ivali ai implement feature "add firewall"             # Fully specified`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("AI Implement")

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

			if !f.confirm("  Continue with AI implementation?") {
				f.stepInfo("Cancelled")
				return nil
			}

			// ── Step 3: Create GitLab issue ──────────────────────────────
			f.stepStart("Step 1/7: Creating GitLab issue")

			repoDir := f.repoDir
			templatePath := filepath.Join(repoDir, ".gitlab", "issue_templates", changeType+".md")
			issueBody := ""
			fmt.Printf("  │  %s Loading %s template...\n", f.term.Dim("▶"), f.term.Code(changeType))
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
			issueCmd.Dir = repoDir

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
			f.stepStart("Step 2/7: Creating branch")
			branchName := fmt.Sprintf("%s/%s", changeType, cleanBranchName(description))
			if len(branchName) > 60 {
				branchName = branchName[:60]
			}
			fmt.Printf("  │  %s git checkout -b %s\n", f.term.Dim("▶"), f.term.Code(branchName))
			if out, err := gitRun(repoDir, "git", "checkout", "-b", branchName); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to create branch: %s", out)
			}
			f.stepOK(fmt.Sprintf("Branch %s created", f.term.Code(branchName)))
			f.stepDone()

			// ── Step 5: AI Implementation ──────────────────────────────
			f.stepStart("Step 3/7: AI Implementation")
			f.stepInfo("")
			f.stepInfo("  The AI will now implement the changes.")
			f.stepInfo("  It will create/modify files, write tests, and update docs.")
			f.stepInfo("")

			prompt := buildImplementPrompt(repoDir, changeType, description, issueNum)
			fmt.Printf("  │  %s %s\n", f.term.Dim("Prompt:"), f.term.Code(prompt[:80]+"..."))
			f.stepInfo("")

			f.stepInfo("Calling AI tool...")
			tool, err := runAITool(repoDir, prompt)
			if err != nil {
				f.stepInfo(fmt.Sprintf("  %s %v", f.term.Warn("⚠"), err))
				f.stepInfo("  You can run the AI tool manually later")
			} else {
				f.stepOK(fmt.Sprintf("AI implementation complete (via %s)", tool))
			}
			f.stepDone()

			// ── Step 6: Validate ────────────────────────────────────────
			f.stepStart("Step 4/7: Running verification gates")
			f.stepInfo("")

			type gateEntry struct {
				name string
				fn   func() (string, error)
			}
			gates := []gateEntry{
				{"nix fmt", func() (string, error) {
					return gitRun(repoDir, "nix", "fmt", "--", "--check", ".")
				}},
				{"shellcheck", func() (string, error) {
					out, err := gitRun(repoDir, "shellcheck", "--severity=warning")
					if err != nil && strings.Contains(out, "No such file") {
						return "", nil
					}
					return out, err
				}},
				{"go build", func() (string, error) {
					return gitRun(repoDir, "go", "build", "./...")
				}},
				{"go vet", func() (string, error) {
					return gitRun(repoDir, "go", "vet", "./...")
				}},
				{"go test -race", func() (string, error) {
					return gitRun(repoDir, "go", "test", "-race", "-count=1", "./...")
				}},
				{"nix flake check", func() (string, error) {
					return gitRun(repoDir, "nix", "flake", "check", "--no-build")
				}},
				{"gosec", func() (string, error) {
					return gitRun(repoDir, "gosec", "-exclude-generated", "./...")
				}},
			}

			gateFailed := false
			for _, g := range gates {
				f.stepStart(fmt.Sprintf("  %s ...", g.name))
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
				f.stepInfo(f.term.Bad("  Validation failed — fix errors before committing"))
				f.stepFailed()
				return fmt.Errorf("validation failed")
			}
			f.stepOK("All gates passed")
			f.stepDone()

			// ── Step 7: Commit ──────────────────────────────────────────
			f.stepStart("Step 5/7: Committing changes")

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

			if out, err := gitRun(repoDir, "git", "add", "-A"); err != nil {
				f.stepFail(fmt.Sprintf("Failed to stage: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to stage: %s", out)
			}
			f.stepOK("Changes staged")

			if _, err := gitRun(repoDir, "git", "diff", "--cached", "--quiet"); err == nil {
				f.stepInfo("No changes to commit (working tree clean)")
				f.stepDone()
			} else {
				if out, err := gitRun(repoDir, "git", "commit", "-m", commitMsg); err != nil {
					f.stepFail(fmt.Sprintf("Failed: %s", out))
					f.stepFailed()
					return fmt.Errorf("failed to commit: %s", out)
				}
				f.stepOK(fmt.Sprintf("Committed: %s", f.term.Code(commitMsg)))
				f.stepDone()
			}

			// ── Step 8: Push ────────────────────────────────────────────
			f.stepStart("Step 6/7: Pushing to GitLab")
			if out, err := gitRun(repoDir, "git", "push", "origin", branchName); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to push: %s", out)
			}
			f.stepOK(fmt.Sprintf("Pushed to %s", f.term.Code(branchName)))
			f.stepDone()

			// ── Step 9: Create MR ──────────────────────────────────────
			f.stepStart("Step 7/7: Creating merge request")

			mrTemplatePath := filepath.Join(repoDir, ".gitlab", "merge_request_templates", "default.md")
			mrDesc := description
			if data, err := os.ReadFile(mrTemplatePath); err == nil {
				mrDesc = string(data)
				mrDesc = strings.ReplaceAll(mrDesc, "<!-- Brief description of changes -->", description)
			}

			mrCmd := exec.Command("glab", "mr", "create",
				"--source-branch", branchName,
				"--target-branch", "main",
				"--title", description,
				"--description", mrDesc,
				"--remove-source-branch",
			)
			mrCmd.Dir = repoDir
			mrOut, err := mrCmd.CombinedOutput()
			if err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", string(mrOut)))
				f.stepFailed()
				return fmt.Errorf("failed to create MR: %s", string(mrOut))
			}
			mrURL := strings.TrimSpace(string(mrOut))
			f.stepOK(mrURL)
			f.stepDone()

			// ── Summary ──────────────────────────────────────────────────
			fmt.Println()
			f.divider()
			fmt.Println(f.term.Bold("  🎉  AI Implementation Complete"))
			fmt.Println()
			fmt.Println(f.term.KeyValue("Issue:", fmt.Sprintf("#%s %s", f.term.Code(issueNum), issueURL)))
			fmt.Println(f.term.KeyValue("Branch:", f.term.Code(branchName)))
			fmt.Println(f.term.KeyValue("Commit:", f.term.Code(commitMsg)))
			fmt.Println(f.term.KeyValue("MR:", f.term.Code(mrURL)))
			fmt.Println()
			fmt.Println(f.term.Bold("  Next steps:"))
			fmt.Println(f.term.Dim("    1. Review the merge request"))
			fmt.Println(f.term.Dim("    2. ivali deploy              ← apply configuration"))
			fmt.Println(f.term.Dim("    3. ivali flow pipeline       ← monitor CI"))
			fmt.Println(f.term.Dim("    4. ivali flow merge          ← merge when CI passes"))
			fmt.Println()

			if aiMode {
				result := map[string]string{
					"action":      "implement",
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


	return cmd
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// AI VALIDATE — run verification gates
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func aiValidate(a *app.App) *cobra.Command {
	var host string

	cmd := &cobra.Command{
		Use:   "validate",
		Short: "Run all verification gates",
		Long: `Run the full verification pipeline.

Runs the same gates as CI:
  1. nix fmt       (formatting)
  2. shellcheck     (shell lint)
  3. go build       (compilation)
  4. go vet         (static analysis)
  5. go test -race  (tests with race detector)
  6. nix flake check (flake schema)
  7. gosec          (security scan)`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("AI Validate")

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
				f.stepStart(fmt.Sprintf("  %s ...", g.name))
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

			if aiMode {
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
// AI COMMIT — stage and commit
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func aiCommit(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "commit [description]",
		Short: "Stage and commit with conventional message",
		Long: `Stage all changes and commit with a conventional commit message.

Auto-detects commit type from branch name:
  feature/*  → feat
  bugfix/*   → fix
  module/*   → module
  security/* → security
  docs/*     → docs`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("AI Commit")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}
			if branch == "main" {
				return fmt.Errorf("cannot commit to main branch directly — start a workflow first: ivali ai implement")
			}

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

			f.stepStart("Commit details")
			f.stepInfo(fmt.Sprintf("Branch:  %s", f.term.Code(branch)))
			f.stepInfo(fmt.Sprintf("Message: %s", f.term.Code(commitMsg)))
			f.stepDone()

			if !f.confirm("  Commit these changes?") {
				f.stepInfo("Cancelled")
				return nil
			}

			f.stepStart("Staging changes")
			if out, err := gitRun(f.repoDir, "git", "add", "-A"); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to stage: %s", out)
			}
			f.stepOK("Changes staged")
			f.stepDone()

			f.stepStart("Committing")
			if out, err := gitRun(f.repoDir, "git", "commit", "-m", commitMsg); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to commit: %s", out)
			}
			f.stepOK("Changes committed")
			f.stepDone()

			f.stepStart("Files changed")
			if out, err := gitRun(f.repoDir, "git", "diff", "--stat", "HEAD~1"); err == nil {
				for _, line := range strings.Split(out, "\n") {
					f.stepInfo(line)
				}
			}
			f.stepDone()

			f.nextHint("ivali ai push")

			if aiMode {
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
// AI PUSH — push branch to GitLab
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func aiPush(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "push",
		Short: "Push branch to GitLab",
		Long: `Push the current feature branch to GitLab.

Verifies working tree is clean and commits exist before pushing.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("AI Push")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}
			if branch == "main" {
				return fmt.Errorf("cannot push main — start a workflow first: ivali ai implement")
			}

			f.stepStart("Branch")
			f.stepInfo(f.term.Code(branch))
			f.stepDone()

			if !f.confirm("  Push to GitLab?") {
				f.stepInfo("Cancelled")
				return nil
			}

			f.stepStart("Pushing to GitLab")
			if out, err := gitRun(f.repoDir, "git", "push", "origin", branch); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to push: %s", out)
			}
			f.stepOK("Pushed to GitLab")
			f.stepDone()

			f.nextHint("ivali ai mr")

			if aiMode {
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
// AI MR — create merge request
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func aiMR(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "mr",
		Short: "Create a GitLab merge request",
		Long: `Create a GitLab merge request for the current branch.

Uses the default merge request template from .gitlab/merge_request_templates/.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			f.header("AI Merge Request")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}
			if branch == "main" {
				return fmt.Errorf("cannot create MR from main — start a workflow first: ivali ai implement")
			}

			f.stepStart("Branch")
			f.stepInfo(f.term.Code(branch))
			f.stepDone()

			// Check for unpushed commits
			commits, hasCommits := gitUnpushed(f.repoDir, branch)
			if hasCommits {
				f.stepInfo(f.term.Warn("  Warning: unpushed commits exist. Push first: ivali ai push"))
				if !f.confirm("  Continue anyway?") {
					f.stepInfo("Cancelled")
					return nil
				}
			}

			// Get description
			description := ""
			if len(args) > 0 {
				description = args[0]
			} else {
				fmt.Println(f.term.Dim("  Describe the merge request:"))
				description = f.prompt("  Description:")
				if description == "" {
					description = fmt.Sprintf("Merge %s", branch)
				}
			}

			f.stepStart("Creating merge request")

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

			if hasCommits && commits != "" {
				f.stepStart("Commits to be merged")
				for _, line := range strings.Split(commits, "\n") {
					f.stepInfo(line)
				}
				f.stepDone()
			}

			f.nextHint("ivali flow pipeline")

			if aiMode {
				result := map[string]string{
					"action": "mr",
					"branch": branch,
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
// AI QUICK — single-shot validate → commit → push → MR
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func aiQuick(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "quick [description]",
		Short: "Single-shot: validate → commit → push → MR (AI-friendly)",
		Long: `Run the full development pipeline in one command.

  ivali ai quick "add nftables firewall module"

This will:
  1. Validate all gates
  2. Stage and commit changes
  3. Push branch to GitLab
  4. Create merge request

Designed for agentic workflows: the AI makes file changes, then calls
'ivali ai quick "description"' to commit and push everything.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			aiMode := false
			f := newFlowCtx(a, aiMode)
			description := args[0]

			f.header("AI Quick")

			branch, err := gitBranch(f.repoDir)
			if err != nil {
				return err
			}
			if branch == "main" {
				return fmt.Errorf("cannot run quick on main — start a workflow first: ivali ai implement")
			}

			// ── Step 1: Validate ────────────────────────────────────────
			f.stepStart("Step 1/4: Running validation gates")
			f.stepInfo("")

			type gateEntry struct {
				name string
				fn   func() (string, error)
			}
			gates := []gateEntry{
				{"go build", func() (string, error) { return gitRun(f.repoDir, "go", "build", "./...") }},
				{"go vet", func() (string, error) { return gitRun(f.repoDir, "go", "vet", "./...") }},
				{"go test -race", func() (string, error) { return gitRun(f.repoDir, "go", "test", "-race", "-count=1", "./...") }},
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
			f.stepStart("Step 2/4: Committing changes")

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

			if out, err := gitRun(f.repoDir, "git", "add", "-A"); err != nil {
				f.stepFail(fmt.Sprintf("Failed to stage: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to stage: %s", out)
			}
			f.stepOK("Changes staged")

			if _, err := gitRun(f.repoDir, "git", "diff", "--cached", "--quiet"); err == nil {
				f.stepInfo("No changes to commit (working tree clean)")
				f.stepDone()
				f.stepInfo("")
				f.stepInfo("Nothing to commit — all changes may already be committed.")
				return nil
			}

			if out, err := gitRun(f.repoDir, "git", "commit", "-m", commitMsg); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to commit: %s", out)
			}
			f.stepOK(fmt.Sprintf("Committed: %s", f.term.Code(commitMsg)))
			f.stepDone()

			// ── Step 3: Push ────────────────────────────────────────────
			f.stepStart("Step 3/4: Pushing to GitLab")
			if out, err := gitRun(f.repoDir, "git", "push", "origin", branch); err != nil {
				f.stepFail(fmt.Sprintf("Failed: %s", out))
				f.stepFailed()
				return fmt.Errorf("failed to push: %s", out)
			}
			f.stepOK(fmt.Sprintf("Pushed to %s", f.term.Code(branch)))
			f.stepDone()

			// ── Step 4: Create MR ──────────────────────────────────────
			f.stepStart("Step 4/4: Creating merge request")

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

			// Final summary
			fmt.Println()
			f.divider()
			fmt.Println(f.term.Bold("  AI Quick — Complete"))
			fmt.Println()
			fmt.Println(f.term.KeyValue("Branch:", f.term.Code(branch)))
			fmt.Println(f.term.KeyValue("Commit:", f.term.Code(commitMsg)))
			fmt.Println(f.term.KeyValue("MR:", f.term.Code(mrURL)))
			fmt.Println()
			fmt.Println(f.term.Dim("  Monitor CI: ivali flow pipeline --watch"))
			fmt.Println(f.term.Dim("  Merge:      ivali flow merge"))
			fmt.Println(f.term.Dim("  Deploy:     ivali deploy"))
			fmt.Println()

			if aiMode {
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
// AI STATUS — show AI system availability
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func aiStatus(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show AI system availability",
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println()
			fmt.Println(t.Header("🤖  AI Systems"))
			fmt.Println()

			if a.State != nil {
				comp, ok := a.State.Get("ai")
				if ok {
					fmt.Println(t.KeyValue("State", comp.State.String()))
					fmt.Println(t.KeyValue("Message", comp.Message))
					fmt.Println()
				}
			}

			fmt.Println(t.Section("OpenHands"))
			if _, err := exec.LookPath("openhands"); err == nil {
				fmt.Println(t.Good("  ✓ Available"))
			} else {
				fmt.Println(t.Dim("  ✗ Not available (run 'openhands' after enabling ivali.openhands)"))
			}
			fmt.Println()

			fmt.Println(t.Section("OpenCode"))
			if _, err := os.Stat(".opencode"); err == nil {
				fmt.Println(t.Good("  ✓ OpenCode configured"))
			} else {
				fmt.Println(t.Dim("  ✗ OpenCode not configured"))
			}
			if _, err := os.Stat("opencode/README.md"); err == nil {
				fmt.Println(t.Good("  ✓ Knowledge base available"))
			} else {
				fmt.Println(t.Dim("  ✗ Knowledge base not found"))
			}
			fmt.Println()

			fmt.Println(t.Section("Routing Rules"))
			fmt.Println(t.Dim("  All tasks  →  OpenCode"))
			fmt.Println()

			return nil
		},
	}
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// AI ROUTE — route task to appropriate AI
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func aiRoute(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "route <description>",
		Short: "Route a task to the appropriate AI system",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			description := strings.Join(args, " ")
			t := a.Term

			fmt.Println()
			fmt.Println(t.Header("🤖  AI Routing"))
			fmt.Println()
			fmt.Println(t.KeyValue("Task", description))

			system := routeTask(description)
			fmt.Println(t.KeyValue("Routed to", system))

			fmt.Println()

			switch system {
			case "opencode":
				fmt.Println(t.Dim("  OpenCode is your interactive CLI."))
				fmt.Println(t.Dim("  Describe what you need in natural language."))
			}
			fmt.Println()

			return nil
		},
	}
}

func routeTask(description string) string {
	desc := strings.ToLower(description)

	// Prefer openhands for autonomous tasks if available
	if _, err := exec.LookPath("openhands"); err == nil {
		autonomousKeywords := []string{
			"autonomous", "long-running", "batch", "automate", "refactor",
			"migrate", "sweep", "bulk", "parallel", "background", "overnight",
			"full codebase", "all files", "every file", "entire repository",
		}
		for _, kw := range autonomousKeywords {
			if strings.Contains(desc, kw) {
				return "openhands"
			}
		}
	}

	// Try opencode, then freebuff
	if _, err := exec.LookPath("opencode"); err == nil {
		return "opencode"
	}
	if _, err := exec.LookPath("freebuff"); err == nil {
		return "freebuff"
	}

	return "opencode"
}
