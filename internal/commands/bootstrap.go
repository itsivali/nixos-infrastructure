package commands

import (
	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdBootstrap(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "bootstrap",
		Short: "Generate repository modules from templates",
		Long:  `Bootstrap generates new modules following repository conventions. Never duplicate code.`,
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "shell [name]",
			Short: "Generate a shell module",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				return nil
			},
		},
		&cobra.Command{
			Use:   "editor [name]",
			Short: "Generate an editor module",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				return nil
			},
		},
		&cobra.Command{
			Use:   "service [name]",
			Short: "Generate a service module",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				return nil
			},
		},
		&cobra.Command{
			Use:   "package [name]",
			Short: "Generate a package set",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				return nil
			},
		},
		&cobra.Command{
			Use:   "module [name]",
			Short: "Generate a NixOS domain module",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				return nil
			},
		},
	)

	return cmd
}
