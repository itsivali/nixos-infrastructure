package commands

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

func CmdCompletion(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "completion [bash|zsh|fish|powershell]",
		Short: "Generate shell completion script",
		Long: `Generate shell completion script for the ivali CLI.

To enable completions, source the output:

  bash:
    source <(ivali completion bash)
    or add to ~/.bashrc:
      echo 'source <(ivali completion bash)' >> ~/.bashrc

  zsh:
    source <(ivali completion zsh)
    or add to ~/.zshrc:
      echo 'source <(ivali completion zsh)' >> ~/.zshrc

  fish:
    ivali completion fish | source
    or install:
      ivali completion fish > ~/.config/fish/completions/ivali.fish`,
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			shell := args[0]

			switch shell {
			case "bash":
				return cmd.Root().GenBashCompletion(os.Stdout)
			case "zsh":
				return cmd.Root().GenZshCompletion(os.Stdout)
			case "fish":
				return cmd.Root().GenFishCompletion(os.Stdout, true)
			case "powershell":
				return cmd.Root().GenPowerShellCompletion(os.Stdout)
			default:
				return fmt.Errorf("unsupported shell: %s (use bash, zsh, fish, or powershell)", shell)
			}
		},
	}

	return cmd
}
