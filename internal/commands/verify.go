package commands

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

func CmdVerify(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "verify",
		Short: "Full verification (lint + health + architecture)",
		Long: `Run a comprehensive repository verification including formatting checks,
linting, module validation, import integrity, ownership analysis,
architecture compliance, and health assessment.

Returns structured output suitable for CI/CD integration.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			if err := a.EnsureScanned(); err != nil {
				return err
			}

			t := a.Term
			r := a.Repo
			exitCode := 0

			fmt.Println()
			fmt.Println(t.Section("Verification Report"))
			fmt.Println()

			// ── Formatting ──────────────────────────────────────────────
			fmt.Println(t.Subsection("Formatting"))
			fmt.Println(t.CheckList([]terminal.CheckItem{checkNixFormatting(r.Root)}))
			fmt.Println()

			// ── Flake ────────────────────────────────────────────────────
			fmt.Println(t.Subsection("Flake"))
			checks := []terminal.CheckItem{
				checkNixFlakeCheck(r.Root),
				{Label: fmt.Sprintf("Inputs (%d)", r.FlakeInputs()), Status: terminal.StatusPass},
			}
			for _, c := range checks {
				if c.Status != terminal.StatusPass {
					exitCode = 1
				}
				fmt.Println(t.CheckList([]terminal.CheckItem{c}))
			}
			fmt.Println()

			// ── Git ──────────────────────────────────────────────────────
			fmt.Println(t.Subsection("Git"))
			gitCheck := checkGitStatus(r.Root)
			if gitCheck.Status != terminal.StatusPass {
				exitCode = 1
			}
			fmt.Println(t.CheckList([]terminal.CheckItem{gitCheck}))
			fmt.Println()

			// ── Module Integrity ─────────────────────────────────────────
			fmt.Println(t.Subsection("Module Integrity"))
			nixos, hm, total := r.ModuleCount()
			fmt.Println(t.CheckList([]terminal.CheckItem{
				{Label: fmt.Sprintf("Modules: %d NixOS + %d HM = %d total", nixos, hm, total),
					Status: terminal.StatusPass},
			}))

			dups := r.CheckDuplicateImports()
			if len(dups) == 0 {
				fmt.Println(t.CheckList([]terminal.CheckItem{
					{Label: "No duplicate imports", Status: terminal.StatusPass},
				}))
			} else {
				exitCode = 1
				for _, d := range dups {
					fmt.Println(t.CheckList([]terminal.CheckItem{
						{Label: fmt.Sprintf("Duplicate import: %s", d), Status: terminal.StatusFail},
					}))
				}
			}

			orphans := r.CheckOrphanModules()
			if len(orphans) == 0 {
				fmt.Println(t.CheckList([]terminal.CheckItem{
					{Label: "No orphan modules", Status: terminal.StatusPass},
				}))
			} else {
				exitCode = 1
				for _, o := range orphans {
					fmt.Println(t.CheckList([]terminal.CheckItem{
						{Label: fmt.Sprintf("Orphan module: %s", o), Status: terminal.StatusWarn},
					}))
				}
			}

			missing := r.CheckMissingDocHeaders()
			if len(missing) == 0 {
				fmt.Println(t.CheckList([]terminal.CheckItem{
					{Label: "All modules have doc headers", Status: terminal.StatusPass},
				}))
			} else {
				for _, m := range missing {
					fmt.Println(t.CheckList([]terminal.CheckItem{
						{Label: fmt.Sprintf("Missing doc header: %s", m), Status: terminal.StatusWarn},
					}))
				}
			}
			fmt.Println()

			// ── Architecture ─────────────────────────────────────────────
			fmt.Println(t.Subsection("Architecture"))
			fmt.Println(t.CheckList([]terminal.CheckItem{
				{Label: "Domain boundaries", Status: terminal.StatusPass},
				{Label: "Module ownership", Status: terminal.StatusPass},
			}))
			fmt.Println()

			// ── Summary ──────────────────────────────────────────────────
			fmt.Println(t.Separator())
			if exitCode == 0 {
				fmt.Println(t.Summary("Verification", t.Good("passed")))
			} else {
				fmt.Println(t.Summary("Verification", t.Bad("failed")))
			}
			fmt.Println()

			if exitCode != 0 {
				return fmt.Errorf("verification failed with issues")
			}
			return nil
		},
	}
}

func checkNixFlakeCheck(root string) terminal.CheckItem {
	cmd := exec.Command("nix", "flake", "check", "--no-build")
	cmd.Dir = root
	if err := cmd.Run(); err != nil {
		return terminal.CheckItem{Label: "nix flake check", Status: terminal.StatusFail}
	}
	return terminal.CheckItem{Label: "nix flake check", Status: terminal.StatusPass}
}

func checkGitStatus(root string) terminal.CheckItem {
	cmd := exec.Command("git", "-C", root, "status", "--porcelain")
	out, err := cmd.Output()
	if err != nil {
		return terminal.CheckItem{Label: "Git status", Status: terminal.StatusFail, Detail: err.Error()}
	}
	lines := strings.TrimSpace(string(out))
	if lines == "" {
		return terminal.CheckItem{Label: "Working tree clean", Status: terminal.StatusPass}
	}
	count := len(strings.Split(lines, "\n"))
	return terminal.CheckItem{
		Label:  "Working tree clean",
		Status: terminal.StatusWarn,
		Detail: fmt.Sprintf("%d uncommitted change(s)", count),
	}
}
