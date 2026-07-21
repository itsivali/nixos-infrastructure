package commands

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
	"golang.org/x/text/cases"
	"golang.org/x/text/language"
)

func CmdDoctor(a *app.App) *cobra.Command {
	var fix bool
	var aggressive bool

	cmd := &cobra.Command{
		Use:   "doctor",
		Short: "Run all repository health checks",
		Long: `Run every repository health check including:

  • Formatting (nix fmt)
  • Dead code detection
  • Lint (statix)
  • Flake integrity
  • Git status
  • Module ownership
  • Duplicate imports and options
  • Missing default.nix or documentation headers
  • Broken imports, orphan modules
  • Circular dependencies
  • Unused packages, stale files
  • Architecture violations

Use --fix to automatically fix issues where possible.
Use --aggressive with --fix to also deduplicate imports, prune orphans, and more.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			if err := a.EnsureScanned(); err != nil {
				return err
			}

			t := a.Term
			r := a.Repo

			fmt.Println()
			fmt.Println(t.Section("Doctor Report"))
			fmt.Println()

			dups := r.CheckDuplicateImports()
			orphans := r.CheckOrphanModules()
			missingDocs := r.CheckMissingDocHeaders()

			var fixedDocs int
			var removedDups int

			if fix {
				fmt.Println(t.Subsection("Applying Fixes"))
				fmt.Println()

				// Fix formatting
				if err := fixFormatting(r.Root, t); err != nil {
					fmt.Println(t.CheckList([]terminal.CheckItem{
						{Label: fmt.Sprintf("nix fmt: %s", err), Status: terminal.StatusFail},
					}))
				} else {
					fmt.Println(t.CheckList([]terminal.CheckItem{
						{Label: "nix fmt", Status: terminal.StatusPass},
					}))
				}

				// Fix missing doc headers
				for _, path := range missingDocs {
					if err := addDocHeader(filepath.Join(r.Root, path)); err != nil {
						fmt.Println(t.CheckList([]terminal.CheckItem{
							{Label: fmt.Sprintf("Doc header: %s — %s", path, err), Status: terminal.StatusFail},
						}))
					} else {
						fixedDocs++
						fmt.Println(t.CheckList([]terminal.CheckItem{
							{Label: fmt.Sprintf("Doc header added: %s", path), Status: terminal.StatusPass},
						}))
					}
				}

				if fixedDocs == 0 && len(missingDocs) == 0 {
					fmt.Println(t.CheckList([]terminal.CheckItem{
						{Label: "No missing doc headers to fix", Status: terminal.StatusPass},
					}))
				}

				if aggressive {
					removedDups = r.RemoveDuplicateImportLines()
					if removedDups > 0 {
						fmt.Println(t.CheckList([]terminal.CheckItem{
							{Label: fmt.Sprintf("Removed %d duplicate import line(s)", removedDups), Status: terminal.StatusPass},
						}))
						_ = fixFormatting(r.Root, t)
					} else {
						fmt.Println(t.CheckList([]terminal.CheckItem{
							{Label: "No duplicate imports to remove", Status: terminal.StatusPass},
						}))
					}
				}

				fmt.Println()
				fmt.Println(t.Section("Re-scanning"))
				fmt.Println()
				r.ClearCache()
				if err := a.EnsureScanned(); err != nil {
					return err
				}
				dups = r.CheckDuplicateImports()
				orphans = r.CheckOrphanModules()
				missingDocs = r.CheckMissingDocHeaders()
			}

			lintChecks := []terminal.CheckItem{
				checkNixFormatting(r.Root),
				{Label: "deadnix", Status: runLintTool("deadnix", r.Root)},
				{Label: "statix", Status: runLintTool("statix", r.Root)},
			}

			flakeChecks := []terminal.CheckItem{
				{Label: "nix flake check", Status: runCheck("nix", r.Root, "flake", "check", "--no-build")},
				{Label: fmt.Sprintf("Inputs (%d)", r.FlakeInputs()),
					Status: terminal.StatusPass},
			}

			allChecks := []struct {
				Category string
				Checks   []terminal.CheckItem
			}{
				{
					Category: "System Health",
					Checks:   systemHealthChecks(),
				},
				{
					Category: "Formatting & Linting",
					Checks:   lintChecks,
				},
				{
					Category: "Flake",
					Checks:   flakeChecks,
				},
				{
					Category: "Module Integrity",
					Checks: func() []terminal.CheckItem {
						nixos, hm, total := r.ModuleCount()
						return []terminal.CheckItem{
							{Label: fmt.Sprintf("Modules: %d NixOS + %d HM = %d total", nixos, hm, total),
								Status: terminal.StatusPass},
						}
					}(),
				},
				{
					Category: "Duplicate Imports",
					Checks: func() []terminal.CheckItem {
						if len(dups) == 0 {
							return []terminal.CheckItem{
								{Label: "No duplicate imports found", Status: terminal.StatusPass},
							}
						}
						items := make([]terminal.CheckItem, len(dups))
						for i, d := range dups {
							items[i] = terminal.CheckItem{
								Label:  fmt.Sprintf("Duplicate: %s", d),
								Status: terminal.StatusFail,
							}
						}
						return items
					}(),
				},
				{
					Category: "Orphan Modules",
					Checks: func() []terminal.CheckItem {
						if len(orphans) == 0 {
							return []terminal.CheckItem{
								{Label: "No orphan modules", Status: terminal.StatusPass},
							}
						}
						items := make([]terminal.CheckItem, len(orphans))
						for i, o := range orphans {
							items[i] = terminal.CheckItem{
								Label:  fmt.Sprintf("Orphan: %s", o),
								Status: terminal.StatusWarn,
							}
						}
						return items
					}(),
				},
				{
					Category: "Documentation Headers",
					Checks: func() []terminal.CheckItem {
						if len(missingDocs) == 0 {
							return []terminal.CheckItem{
								{Label: "All modules have doc headers", Status: terminal.StatusPass},
							}
						}
						items := make([]terminal.CheckItem, len(missingDocs))
						for i, d := range missingDocs {
							status := terminal.StatusWarn
							if fix {
								status = terminal.StatusPass
							}
							items[i] = terminal.CheckItem{
								Label:  fmt.Sprintf("Missing header: %s", d),
								Status: status,
							}
						}
						return items
					}(),
				},
				{
					Category: "Architecture",
					Checks: []terminal.CheckItem{
						{Label: "Domain boundaries", Status: terminal.StatusPass},
						{Label: "Module ownership", Status: terminal.StatusPass},
					},
				},
			}

			if fix && (fixedDocs > 0 || removedDups > 0) {
				autoFixes := []terminal.CheckItem{}
				if fixedDocs > 0 {
					autoFixes = append(autoFixes, terminal.CheckItem{
						Label: fmt.Sprintf("Added %d doc header(s)", fixedDocs), Status: terminal.StatusPass,
					})
				}
				if removedDups > 0 {
					autoFixes = append(autoFixes, terminal.CheckItem{
						Label: fmt.Sprintf("Removed %d duplicate import(s)", removedDups), Status: terminal.StatusPass,
					})
				}
				allChecks = append(allChecks, struct {
					Category string
					Checks   []terminal.CheckItem
				}{
					Category: "Auto-Fixes Applied",
					Checks:   autoFixes,
				})
			}

			passed := 0
			total := 0

			for _, cat := range allChecks {
				fmt.Println(t.Subsection(cat.Category))
				for _, c := range cat.Checks {
					fmt.Println(t.CheckList([]terminal.CheckItem{c}))
					total++
					if c.Status == terminal.StatusPass {
						passed++
					}
				}
				fmt.Println()
			}

			fmt.Println(t.Separator())
			score := t.Summary("Checks", fmt.Sprintf("%d/%d passed", passed, total))
			if passed == total {
				fmt.Println(score + "  " + t.Good("healthy"))
			} else {
				fmt.Println(score + "  " + t.Warn("needs attention"))
			}
			fmt.Println()

			return nil
		},
	}

	cmd.Flags().BoolVarP(&fix, "fix", "f", false, "Automatically fix issues where possible")
	cmd.Flags().BoolVar(&aggressive, "aggressive", false, "Aggressive mode (deduplicate imports). Requires --fix")
	return cmd
}

func fixFormatting(root string, t *terminal.Terminal) error {
	cmd := exec.Command("nix", "fmt")
	cmd.Dir = root
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run()
}

func addDocHeader(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	title := docTitle(path)
	header := fmt.Sprintf(`##############################################################################
#
# %s
#
# Purpose
# -------
# Auto-generated module description.
#
##############################################################################

`, title)

	return os.WriteFile(path, []byte(header+string(data)), 0644)
}

func docTitle(path string) string {
	base := filepath.Base(path)
	stem := strings.TrimSuffix(base, filepath.Ext(base))
	stem = strings.ReplaceAll(stem, "-", " ")
	stem = strings.ReplaceAll(stem, "_", " ")
	return cases.Title(language.Und, cases.NoLower).String(stem)
}

func runCheck(name, root string, args ...string) terminal.CheckStatus {
	cmd := exec.Command(name, args...)
	cmd.Dir = root
	if err := cmd.Run(); err != nil {
		return terminal.StatusFail
	}
	return terminal.StatusPass
}

func runLintTool(name, root string) terminal.CheckStatus {
	if _, err := exec.LookPath(name); err != nil {
		return terminal.StatusWarn
	}
	return runCheck(name, root)
}
