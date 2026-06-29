package commands

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/parser"
	"github.com/willisivali/nixos-infrastructure/internal/scanner"
)

func CmdExplain(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "explain [module]",
		Short: "Explain a module or option",
		Long: `Display detailed information about a module, including
its purpose, ownership, imports, declared options, type, and
category.

Provide a full or partial path to the module.`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			if err := a.EnsureScanned(); err != nil {
				return err
			}

			t := a.Term
			r := a.Repo
			query := args[0]

			mod, info, found := r.FindModule(query)
			if !found {
				fmt.Println()
				fmt.Println(t.Bad("Module not found: ") + t.Code(query))
				fmt.Println()
				return nil
			}

			fmt.Println()
			fmt.Println(t.Section(fmt.Sprintf("Module: %s", mod.RelPath)))
			fmt.Println()

			fmt.Println(t.KeyValue("Category", string(mod.Category)))
			fmt.Println(t.KeyValue("Type", string(mod.Type)))
			fmt.Println(t.KeyValue("Path", mod.Path))
			if mod.LineCount > 0 {
				fmt.Println(t.KeyValue("Lines", fmt.Sprintf("%d", mod.LineCount)))
			}
			fmt.Println()

			if info == nil {
				return nil
			}

			if info.Purpose != "" {
				fmt.Println(t.Subsection("Purpose"))
				fmt.Printf("  %s\n\n", t.Dim(info.Purpose))
			}

			if len(info.Owns) > 0 {
				fmt.Println(t.Subsection("Ownership"))
				for _, o := range info.Owns {
					fmt.Printf("  %s %s\n", t.Dim("•"), o)
				}
				fmt.Println()
			}

			if info.HasOptions {
				fmt.Println(t.Subsection("Options"))
				fmt.Printf("  %s Declares configuration options\n\n", t.Info("i"))
			}

			if len(info.Imports) > 0 {
				fmt.Println(t.Subsection("Imports"))
				for _, imp := range info.Imports {
					fmt.Printf("  %s %s\n", t.Dim("→"), imp)
				}
				fmt.Println()
			}

			if info.IsAutoImport {
				fmt.Println(t.Subsection("Auto-Import"))
				fmt.Printf("  %s Uses auto-import pattern\n\n", t.Info("i"))
			}

			if info.DocHeader != "" {
				fmt.Println(t.Subsection("Documentation"))
				headerLines := strings.Split(info.DocHeader, "\n")
				maxLines := 8
				for i, line := range headerLines {
					if i >= maxLines {
						fmt.Printf("  %s  (+ %d more lines)\n", t.Dim("⋯"), len(headerLines)-maxLines)
						break
					}
					fmt.Printf("  %s\n", t.Code(line))
				}
				fmt.Println()
			}

			parents := findImporters(r.Result.AllModules, r.Parsed, mod.RelPath)
			if len(parents) > 0 {
				fmt.Println(t.Subsection("Imported By"))
				for _, p := range parents {
					fmt.Printf("  %s %s\n", t.Dim("←"), p)
				}
				fmt.Println()
			}

			return nil
		},
	}
}

func findImporters(modules []scanner.Module, parsed map[string]*parser.ModuleInfo, targetRel string) []string {
	var importers []string
	for _, m := range modules {
		if info, ok := parsed[m.Path]; ok {
			for _, imp := range info.Imports {
				resolved := resolveImportRel(m.RelPath, imp)
				if resolved == targetRel {
					importers = append(importers, m.RelPath)
				}
			}
		}
	}
	sort.Strings(importers)
	return importers
}

func resolveImportRel(moduleRel, imp string) string {
	if strings.HasPrefix(imp, "./") || strings.HasPrefix(imp, "../") {
		resolved := filepath.Join(filepath.Dir(moduleRel), imp)
		resolved = filepath.Clean(resolved)
		if !strings.HasSuffix(resolved, ".nix") {
			resolved += "/default.nix"
		}
		return resolved
	}
	return imp
}
