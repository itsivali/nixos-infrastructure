# Module Catalog

## NixOS Domain Modules

| Domain | Location | Key Files |
|--------|----------|-----------|
| **automation** | `automation/` | options.nix, bot-watchdog.nix, channel-bump.nix, common.nix, gitops-reconciler.nix |
| **boot** | `boot/` | kernel.nix, loader.nix, plymouth.nix, resilience.nix, sysctl.nix, ... |
| **cache** | `cache/` |  |
| **caching** | `caching/` |  |
| **ci** | `ci/` | ci-deploy.nix, gitlab-runner.nix |
| **cloud** | `cloud/` | options.nix |
| **configuration.nix** | `configuration.nix/` | configuration.nix |
| **desktop** | `desktop/` | audio.nix, clipboard.nix, colors.nix, environment.nix, fonts.nix, ... |
| **developer** | `developer/` | aliases.nix, antigravity.nix, databases.nix, devops.nix, freebuff.nix, ... |
| **flake.nix** | `flake.nix/` | flake.nix |
| **home** | `home/` | neovim.nix, zed.nix, locale.nix, mime.nix, packages.nix, ... |
| **hosts** | `hosts/` | hardware-configuration.nix, hosts.nix, prague.nix, testvm.nix, tuscany.nix |
| **i18n** | `i18n/` | locale.nix |
| **lib** | `lib/` | auto-imports.nix, go-src.nix, hardware-detection.nix |
| **networking** | `networking/` | networkmanager.nix, time.nix |
| **observability** | `observability/` | options.nix, alerting.nix, alertmanager.nix, alloy.nix, dashboards.nix, ... |
| **recovery** | `recovery/` | backup.nix, deployment-health.nix, rollback.nix |
| **security** | `security/` | apparmor.nix, audit.nix, fail2ban.nix, firewall.nix, hardening.nix, ... |
| **services** | `services/` | ci-notify.nix, ivali-bot-go.nix, config.nix, options.nix, config.nix, ... |
| **ssh** | `ssh/` | options.nix, client.nix, daemon.nix |
| **storage** | `storage/` | btrfs.nix, tmpfs.nix |
| **system** | `system/` | nix.nix, state.nix, users.nix |
| **tests** | `tests/` | automation-smoke.nix, bitwarden-smoke.nix, bot-desktop-smoke.nix, bot-integration.nix, home-manager-smoke.nix, ... |
| **virtualization** | `virtualization/` | docker.nix |

## Home Manager Modules

| Module | Location | Purpose |
|--------|----------|---------|
| default | `home/editors/default.nix` | default |
| neovim | `home/editors/neovim.nix` | neovim |
| zed | `home/editors/zed.nix` | zed |
| default | `home/environment/default.nix` | default |
| locale | `home/environment/locale.nix` | locale |
| mime | `home/environment/mime.nix` | mime |
| packages | `home/environment/packages.nix` | packages |
| session | `home/environment/session.nix` | session |
| variables | `home/environment/variables.nix` | variables |
| xdg | `home/environment/xdg.nix` | xdg |
| default | `home/firefox/default.nix` | default |
| default | `home/git/default.nix` | default |
| delta | `home/git/delta.nix` | delta |
| git | `home/git/git.nix` | Configure Git defaults for the develo... |
| packages | `home/git/packages.nix` | packages |
| default | `home/hyprland/default.nix` | default |
| default | `home/hyprland/clipboard/default.nix` | Auto-generated module description. |
| default | `home/hyprland/dropdown/default.nix` | Auto-generated module description. |
| default | `home/hyprland/emoji/default.nix` | Auto-generated module description. |
| default | `home/hyprland/gamemode/default.nix` | Auto-generated module description. |
| default | `home/hyprland/gnome/default.nix` | default |
| default | `home/hyprland/hypr/default.nix` | default |
| animations | `home/hyprland/hypr/animations.nix` | animations |
| keybindings | `home/hyprland/hypr/keybindings.nix` | Auto-generated module description. |
| monitors | `home/hyprland/hypr/monitors.nix` | Declarative monitor configuration wit... |
| rules | `home/hyprland/hypr/rules.nix` | Window rules, float rules, opacity, a... |
| default | `home/hyprland/hypridle/default.nix` | default |
| default | `home/hyprland/hyprlock/default.nix` | default |
| default | `home/hyprland/hyprpaper/default.nix` | Auto-generated module description. |
| default | `home/hyprland/hyprsunset/default.nix` | Auto-generated module description. |
| default | `home/hyprland/keybindhint/default.nix` | Auto-generated module description. |
| default | `home/hyprland/networkmanager/default.nix` | default |
| default | `home/hyprland/rofi/default.nix` | default |
| default | `home/hyprland/screenshot/default.nix` | Auto-generated module description. |
| default | `home/hyprland/swaync/default.nix` | default |
| default | `home/hyprland/swayosd/default.nix` | default |
| default | `home/hyprland/themes/default.nix` | default |
| gruvbox | `home/hyprland/themes/gruvbox.nix` | gruvbox |
| default | `home/hyprland/wallpaper/default.nix` | Auto-generated module description. |
| default | `home/hyprland/waybar/default.nix` | default |
| style | `home/hyprland/waybar/style.nix` | style |
| default | `home/hyprland/wlogout/default.nix` | default |
| default | `home/identity/default.nix` | default |
| default | `home/services/default.nix` | default |
| auto-format | `home/services/auto-format.nix` | auto-format |
| default | `home/shell/default.nix` | default |
| default | `home/shell/aliases/default.nix` | default |
| development | `home/shell/aliases/development.nix` | development |
| git | `home/shell/aliases/git.nix` | git |
| ivali | `home/shell/aliases/ivali.nix` | ivali |
| navigation | `home/shell/aliases/navigation.nix` | navigation |
| nix | `home/shell/aliases/nix.nix` | nix |
| utilities | `home/shell/aliases/utilities.nix` | utilities |
| default | `home/shell/bitwarden/default.nix` | default |
| cache | `home/shell/bitwarden/cache.nix` | cache |
| completion | `home/shell/bitwarden/completion.nix` | completion |
| env | `home/shell/bitwarden/env.nix` | env |
| default | `home/shell/core/default.nix` | default |
| bash | `home/shell/core/bash.nix` | bash |
| completion | `home/shell/core/completion.nix` | completion |
| history | `home/shell/core/history.nix` | history |
| keybindings | `home/shell/core/keybindings.nix` | keybindings |
| prompt | `home/shell/core/prompt.nix` | Auto-generated module description. |
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
| default | `home/terminal/default.nix` | default |
| kitty | `home/terminal/kitty.nix` | kitty |
