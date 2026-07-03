# Module Catalog

## NixOS Domain Modules

| Domain | Location | Key Files |
|--------|----------|-----------|
| **automation** | `automation/` | options.nix, common.nix, gitops-reconciler.nix |
| **boot** | `boot/` | kernel.nix, loader.nix, sysctl.nix, tpm.nix, zram.nix |
| **ci** | `ci/` | ci-deploy.nix, gitlab-runner.nix |
| **cloud** | `cloud/` |  |
| **configuration.nix** | `configuration.nix/` | configuration.nix |
| **desktop** | `desktop/` | gnome-lean.nix, gpu.nix |
| **developer** | `developer/` | languages.nix, shell.nix |
| **flake.nix** | `flake.nix/` | flake.nix |
| **home** | `home/` | zed.nix, locale.nix, packages.nix, session.nix, variables.nix, ... |
| **hosts** | `hosts/` | hardware-configuration.nix, laptop.nix |
| **i18n** | `i18n/` | locale.nix |
| **lib** | `lib/` | auto-imports.nix |
| **networking** | `networking/` | networkmanager.nix, time.nix |
| **observability** | `observability/` | options.nix, alloy.nix, falco.nix, grafana.nix, journald.nix, ... |
| **recovery** | `recovery/` | deployment-health.nix, rollback.nix |
| **security** | `security/` | apparmor.nix, fail2ban.nix, firewall.nix, hardening.nix, packages.nix, ... |
| **services** | `services/` |  |
| **ssh** | `ssh/` | client.nix |
| **storage** | `storage/` | btrfs.nix, encryption.nix |
| **system** | `system/` | nix.nix, state.nix, users.nix |
| **tests** | `tests/` | laptop-smoke.nix |
| **virtualization** | `virtualization/` | docker.nix |

## Home Manager Modules

| Module | Location | Purpose |
|--------|----------|---------|
| default | `home/editors/default.nix` | default |
| zed | `home/editors/zed.nix` | Auto-generated module description. |
| default | `home/environment/default.nix` | default |
| locale | `home/environment/locale.nix` | locale |
| packages | `home/environment/packages.nix` | packages |
| session | `home/environment/session.nix` | session |
| variables | `home/environment/variables.nix` | variables |
| xdg | `home/environment/xdg.nix` | xdg |
| default | `home/git/default.nix` | default |
| delta | `home/git/delta.nix` | delta |
| git | `home/git/git.nix` | Configure Git defaults for the develo... |
| packages | `home/git/packages.nix` | packages |
| default | `home/identity/default.nix` | default |
| default | `home/services/default.nix` | default |
| auto-format | `home/services/auto-format.nix` | auto-format |
| default | `home/shell/default.nix` | default |
| bitwarden | `home/shell/bitwarden.nix` | bitwarden |
| default | `home/shell/aliases/default.nix` | default |
| development | `home/shell/aliases/development.nix` | development |
| git | `home/shell/aliases/git.nix` | git |
| ivali | `home/shell/aliases/ivali.nix` | ivali |
| navigation | `home/shell/aliases/navigation.nix` | navigation |
| nix | `home/shell/aliases/nix.nix` | nix |
| utilities | `home/shell/aliases/utilities.nix` | utilities |
| default | `home/shell/core/default.nix` | default |
| bash | `home/shell/core/bash.nix` | bash |
| completion | `home/shell/core/completion.nix` | completion |
| history | `home/shell/core/history.nix` | history |
| keybindings | `home/shell/core/keybindings.nix` | keybindings |
| prompt | `home/shell/core/prompt.nix` | prompt |
| zsh | `home/shell/core/zsh.nix` | zsh |
| default | `home/shell/integrations/default.nix` | default |
| atuin | `home/shell/integrations/atuin.nix` | atuin |
| direnv | `home/shell/integrations/direnv.nix` | direnv |
| fzf | `home/shell/integrations/fzf.nix` | fzf |
| zoxide | `home/shell/integrations/zoxide.nix` | zoxide |
| default | `home/shell/tools/default.nix` | default |
| bat | `home/shell/tools/bat.nix` | bat |
| btop | `home/shell/tools/btop.nix` | btop |
| eza | `home/shell/tools/eza.nix` | eza |
| fastfetch | `home/shell/tools/fastfetch.nix` | fastfetch |
| packages | `home/shell/tools/packages.nix` | packages |
