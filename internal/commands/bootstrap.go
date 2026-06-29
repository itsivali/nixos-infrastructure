package commands

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
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
			Use:   "shell [name]",
			Short: "Generate a shell module structure",
			Long:  "Create a Home Manager shell module with aliases, core, integrations, and tools directories.",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				fmt.Println(a.Term.Warn("Bootstrap shell not yet implemented"))
				return nil
			},
		},
		&cobra.Command{
			Use:   "editor [name]",
			Short: "Generate an editor module",
			Long:  "Create a Home Manager editor module skeleton.",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				fmt.Println(a.Term.Warn("Bootstrap editor not yet implemented"))
				return nil
			},
		},
		&cobra.Command{
			Use:   "service [name]",
			Short: "Generate a service module",
			Long:  "Create a service module with default.nix, options, and configuration.",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				fmt.Println(a.Term.Warn("Bootstrap service not yet implemented"))
				return nil
			},
		},
		&cobra.Command{
			Use:   "package [name]",
			Short: "Generate a package set",
			Long:  "Create a new package set under packages/.",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				fmt.Println(a.Term.Warn("Bootstrap package not yet implemented"))
				return nil
			},
		},
		&cobra.Command{
			Use:   "module [name]",
			Short: "Generate a NixOS domain module",
			Long:  "Create a new NixOS domain module with default.nix entry point.",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				if !a.RequireRepo() {
					return nil
				}
				fmt.Println(a.Term.Warn("Bootstrap module not yet implemented"))
				return nil
			},
		},
	)

	return cmd
}
