package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
	"github.com/willisivali/nixos-infrastructure/internal/template"
)

func CmdBootstrap(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "bootstrap",
		Short: "Generate repository modules from templates",
		Long:  `Bootstrap generates new modules following repository conventions. Never duplicate code.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return cmd.Help()
		},
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "module [name]",
			Short: "Generate a NixOS domain module",
			Long:  "Create a new NixOS domain module with default.nix entry point and options skeleton.",
			Args:  cobra.ExactArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				gen := template.New(a.Repo.Root)
				files, err := gen.DomainModule(args[0])
				if err != nil {
					return err
				}
				return writeFiles(a, files, a.Repo.Root)
			},
		},
		&cobra.Command{
			Use:   "service [name]",
			Short: "Generate a service module",
			Long:  "Create a service module with default.nix, options, and configuration.",
			Args:  cobra.ExactArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				gen := template.New(a.Repo.Root)
				files, err := gen.ServiceModule(args[0])
				if err != nil {
					return err
				}
				return writeFiles(a, files, a.Repo.Root)
			},
		},
		&cobra.Command{
			Use:   "shell [name]",
			Short: "Generate a shell module structure",
			Long:  "Create a Home Manager shell module with aliases, core, integrations, and tools directories.",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				gen := template.New(a.Repo.Root)
				name := ""
				if len(args) > 0 {
					name = args[0]
				}
				files, err := gen.ShellModule(name)
				if err != nil {
					return err
				}
				return writeFiles(a, files, a.Repo.Root)
			},
		},
		&cobra.Command{
			Use:   "editor [name]",
			Short: "Generate an editor module",
			Long:  "Create a Home Manager editor module skeleton under home/editors/.",
			Args:  cobra.ExactArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				gen := template.New(a.Repo.Root)
				files, err := gen.EditorModule(args[0])
				if err != nil {
					return err
				}
				return writeFiles(a, files, a.Repo.Root)
			},
		},
		&cobra.Command{
			Use:   "package [name]",
			Short: "Generate a package set",
			Long:  "Create a new package set under packages/ with default.nix, cli.nix, and desktop.nix.",
			Args:  cobra.ExactArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				gen := template.New(a.Repo.Root)
				files, err := gen.PackageSet(args[0])
				if err != nil {
					return err
				}
				return writeFiles(a, files, a.Repo.Root)
			},
		},
	)

	return cmd
}

func writeFiles(a *app.App, files []template.FileSpec, root string) error {
	t := a.Term

	gen := template.New(root)
	if err := gen.Write(files); err != nil {
		return err
	}

	fmt.Println()
	fmt.Println(t.Section("Generated Files"))
	fmt.Println()

	for _, f := range files {
		fmt.Println(t.Good("✓") + "  " + t.Dim(f.Path))
	}

	fmt.Println()
	fmt.Println(t.Info("Run ") + t.Code("ivali scan") + t.Info(" to index the new module."))
	fmt.Println()

	return nil
}
