package commands

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/parser"
	"github.com/itsivali/nixos-infrastructure/internal/scanner"
)

func CmdExtract(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "extract",
		Short: "Analyze and refactor configuration into modules",
		Long: `Analyze the repository and identify configuration that could
be extracted into dedicated modules. Run an extract subcommand
to see what config exists in each domain and refactoring suggestions.

Subcommands:
  shell       Analyze shell configuration (aliases, core, integrations, tools)
  git         Analyze git configuration 
  environment Analyze environment variables and XDG settings`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "shell",
			Short: "Analyze shell configuration for extraction",
			Long: `Scan the repository and identify shell configuration that
belongs in home/shell/ modules. Shows current shell modules,
alias domains, and suggests missing alias categories.`,
			Args: cobra.NoArgs,
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				if err := a.EnsureScanned(); err != nil {
					return err
				}
				return extractShell(a)
			},
		},
		&cobra.Command{
			Use:   "git",
			Short: "Analyze git configuration for extraction",
			Long: `Scan the repository and identify git configuration that
belongs in home/git/ modules. Shows current git modules,
delta config, and git-related packages.`,
			Args: cobra.NoArgs,
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				if err := a.EnsureScanned(); err != nil {
					return err
				}
				return extractGit(a)
			},
		},
		&cobra.Command{
			Use:   "environment",
			Short: "Analyze environment variables for extraction",
			Long: `Scan the repository and identify environment configuration
that belongs in home/environment/ modules. Shows current
env variable groups, XDG settings, and locale config.`,
			Args: cobra.NoArgs,
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				if err := a.EnsureScanned(); err != nil {
					return err
				}
				return extractEnvironment(a)
			},
		},
	)

	return cmd
}

func extractShell(a *app.App) error {
	t := a.Term
	r := a.Repo

	shellMods := filterByPrefix(r.Result.AllModules, "home/shell")

	fmt.Println()
	fmt.Println(t.Section("Shell Module Analysis"))
	fmt.Println()

	// Group by subdirectory
	aliases := filterByPrefix(shellMods, "home/shell/aliases")
	core := filterByPrefix(shellMods, "home/shell/core")
	integrations := filterByPrefix(shellMods, "home/shell/integrations")
	tools := filterByPrefix(shellMods, "home/shell/tools")
	root := filterByPrefix(shellMods, "home/shell/")

	fmt.Println(t.Subsection("Aliases") + "  " + t.Dim(fmt.Sprintf("(%d files)", len(aliases))))
	for _, m := range aliases {
		fmt.Printf("  %s %s\n", t.Dim("•"), t.Code(filepath.Base(m.RelPath)))
	}
	fmt.Println()

	fmt.Println(t.Subsection("Core") + "  " + t.Dim(fmt.Sprintf("(%d files)", len(core))))
	for _, m := range core {
		fmt.Printf("  %s %s\n", t.Dim("•"), t.Code(filepath.Base(m.RelPath)))
	}
	fmt.Println()

	fmt.Println(t.Subsection("Integrations") + "  " + t.Dim(fmt.Sprintf("(%d files)", len(integrations))))
	for _, m := range integrations {
		fmt.Printf("  %s %s\n", t.Dim("•"), t.Code(filepath.Base(m.RelPath)))
	}
	fmt.Println()

	fmt.Println(t.Subsection("Tools") + "  " + t.Dim(fmt.Sprintf("(%d files)", len(tools))))
	for _, m := range tools {
		fmt.Printf("  %s %s\n", t.Dim("•"), t.Code(filepath.Base(m.RelPath)))
	}
	fmt.Println()

	// Check for duplicate alias names
	aliasNames := make(map[string][]string)
	for _, m := range aliases {
		aliasNames[filepath.Base(m.RelPath)] = append(aliasNames[filepath.Base(m.RelPath)], m.RelPath)
	}
	hasDups := false
	for name, paths := range aliasNames {
		if len(paths) > 1 {
			if !hasDups {
				fmt.Println(t.Warn("Duplicate alias files:"))
				hasDups = true
			}
			fmt.Printf("  %s %s appears in %d places\n", t.Dim("•"), name, len(paths))
		}
	}

	rootCount := len(root)
	subCount := len(aliases) + len(core) + len(integrations) + len(tools)
	fmt.Println(t.Separator())
	fmt.Printf("  %s %d files total  •  %d in subdirectories  •  %d at root\n",
		t.Info("∑"), rootCount, subCount, rootCount-subCount)
	fmt.Println()

	return nil
}

func extractGit(a *app.App) error {
	t := a.Term
	r := a.Repo

	gitMods := filterByPrefix(r.Result.AllModules, "home/git")

	fmt.Println()
	fmt.Println(t.Section("Git Module Analysis"))
	fmt.Println()

	fmt.Println(t.Subsection("Git Modules") + "  " + t.Dim(fmt.Sprintf("(%d files)", len(gitMods))))
	for _, m := range gitMods {
		labels := []string{}
		if info, ok := r.Parsed[m.Path]; ok {
			if info.HasOptions {
				labels = append(labels, "options")
			}
			if info.Purpose != "" {
				labels = append(labels, info.Purpose)
			}
		}
		suffix := ""
		if len(labels) > 0 {
			suffix = "  " + t.Dim("("+strings.Join(labels, ", ")+")")
		}
		fmt.Printf("  %s %s%s\n", t.Dim("•"), t.Code(m.RelPath), suffix)
	}
	fmt.Println()

	// Check for git config outside home/git/
	outside := findModulesWithPattern(r.Result.AllModules, r.Parsed, "programs.git")
	if len(outside) > 0 {
		fmt.Println(t.Warn("Git config outside home/git/:"))
		for _, m := range outside {
			fmt.Printf("  %s %s\n", t.Dim("•"), m)
		}
		fmt.Println()
	}

	fmt.Println(t.Subsection("Git Packages"))
	gitPkgs := findGithubPackages(r.Result.AllModules, r.Parsed)
	if len(gitPkgs) > 0 {
		for _, p := range gitPkgs {
			fmt.Printf("  %s %s\n", t.Dim("•"), t.Code(p))
		}
	} else {
		fmt.Printf("  %s\n", t.Dim("  No git-related packages detected in home/git/"))
	}
	fmt.Println()

	fmt.Println(t.Separator())
	fmt.Printf("  %s %d git modules\n", t.Info("∑"), len(gitMods))
	fmt.Println()

	return nil
}

func extractEnvironment(a *app.App) error {
	t := a.Term
	r := a.Repo

	envMods := filterByPrefix(r.Result.AllModules, "home/environment")

	fmt.Println()
	fmt.Println(t.Section("Environment Module Analysis"))
	fmt.Println()

	fmt.Println(t.Subsection("Environment Modules") + "  " + t.Dim(fmt.Sprintf("(%d files)", len(envMods))))
	for _, m := range envMods {
		labels := []string{}
		if info, ok := r.Parsed[m.Path]; ok {
			if info.Purpose != "" {
				labels = append(labels, info.Purpose)
			}
		}
		suffix := ""
		if len(labels) > 0 {
			suffix = "  " + t.Dim("("+strings.Join(labels, ", ")+")")
		}
		fmt.Printf("  %s %s%s\n", t.Dim("•"), t.Code(filepath.Base(m.RelPath)), suffix)
	}

	// Analyze session variables found in parsed headers
	var varModules []string
	for _, m := range envMods {
		if info, ok := r.Parsed[m.Path]; ok && info.Purpose != "" {
			varModules = append(varModules, info.Purpose)
		}
	}

	fmt.Println()
	fmt.Println(t.Subsection("Variables by Module"))
	if len(varModules) > 0 {
		for i, m := range envMods {
			if i < len(varModules) {
				fmt.Printf("  %s %s\n", t.Dim("•"), t.Code(filepath.Base(m.RelPath))+" — "+t.Dim(varModules[i]))
			} else {
				fmt.Printf("  %s %s\n", t.Dim("•"), t.Code(filepath.Base(m.RelPath))+" — "+t.Dim("(no purpose)"))
			}
		}
	} else {
		for _, m := range envMods {
			fmt.Printf("  %s %s\n", t.Dim("•"), t.Code(filepath.Base(m.RelPath)))
		}
	}
	fmt.Println()

	fmt.Println(t.Separator())
	fmt.Printf("  %s %d environment modules\n", t.Info("∑"), len(envMods))
	fmt.Println()

	return nil
}

// Helpers

func filterByPrefix(modules []scanner.Module, prefix string) []scanner.Module {
	var result []scanner.Module
	for _, m := range modules {
		if strings.HasPrefix(m.RelPath, prefix) {
			result = append(result, m)
		}
	}
	sort.Slice(result, func(i, j int) bool {
		return result[i].RelPath < result[j].RelPath
	})
	return result
}

func findModulesWithPattern(modules []scanner.Module, parsed map[string]*parser.ModuleInfo, pattern string) []string {
	var result []string
	for _, m := range modules {
		if strings.Contains(m.RelPath, "home/git") {
			continue
		}
		if info, ok := parsed[m.Path]; ok {
			if info.Purpose != "" && strings.Contains(strings.ToLower(info.Purpose), strings.ToLower(pattern)) {
				result = append(result, m.RelPath)
			}
		}
	}
	sort.Strings(result)
	return result
}

func findGithubPackages(modules []scanner.Module, parsed map[string]*parser.ModuleInfo) []string {
	var result []string
	for _, m := range modules {
		if strings.HasPrefix(m.RelPath, "home/git") && strings.HasSuffix(m.RelPath, ".nix") {
			if info, ok := parsed[m.Path]; ok {
				if info.Purpose != "" {
					result = append(result, m.RelPath+" — "+info.Purpose)
				} else {
					result = append(result, m.RelPath)
				}
			}
		}
	}
	sort.Strings(result)
	return result
}
