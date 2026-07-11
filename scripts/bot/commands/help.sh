#!/usr/bin/env bash
# commands/help.sh — /help — Show command menu with inline category navigation
##############################################################################

_cmd_help() {
  local chat="$1" args="$2"

  local subcmd="${args%% *}"

  case "$subcmd" in
    deployment|deploy)
      _help_deployment "$chat"
      ;;
    monitoring|monitor|mon)
      _help_monitoring "$chat"
      ;;
    desktop|desk)
      _help_desktop "$chat"
      ;;
    system|sys)
      _help_system "$chat"
      ;;
    gitlab|gl)
      _help_gitlab "$chat"
      ;;
    github|gh)
      _help_github "$chat"
      ;;
    *)
      _help_main "$chat"
      ;;
  esac
}

_help_main() {
  local out="🛰 *${HOST}* — Command Reference
━━━━━━━━━━━━━━━━━━━━━━━━━━

_NixOS GitOps bot · long-poll session active_
━━━━━━━━━━━━━━━━━━━━━━━━━━

*Quick Access:*
  \`/status\`  System snapshot     \`/open\`   Launch apps
  \`/deploy\`  Apply config        \`/help\`   This menu
  \`/health\`  Health check        \`/menu\`   Keyboard

_Select a category below for detailed help:_"

  send_inline_keyboard "$chat" "$out" \
    "🚀 Deployment:help_deployment" \
    "📊 Monitoring:help_monitoring" \
    "🖥 Desktop:help_desktop" \
    "🔧 System:help_system" \
    "📦 GitLab:help_gitlab" \
    "🐙 GitHub:help_github"
}

_help_deployment() {
  local out="🚀 *Deployment Commands*
━━━━━━━━━━━━━━━━━━━━━━━━━━

\`/deploy\`
Deploy the current NixOS configuration.
This will:
  • Pull latest changes from Git
  • Build and activate new NixOS generation
  • May take several minutes to complete
  _Requires admin role_

\`/update\`
Update flake inputs and push changes.
  • Pull latest changes from Git
  • Run \`nix flake update\`
  • Commit and push changes
  _Requires admin role_

\`/rollback\`
Revert to the previous NixOS generation.
  • Switch to the previous generation
  • Can be undone with \`/deploy\`
  _Requires admin role_

\`/generations\`
List all NixOS generations with timestamps.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Select another category or_ \`/help\` _for main menu_"

  send_inline_keyboard "$chat" "$out" \
    "◀ Main Menu:help_main" \
    "📊 Monitoring:help_monitoring" \
    "🖥 Desktop:help_desktop" \
    "🔧 System:help_system"
}

_help_monitoring() {
  local out="📊 *Monitoring Commands*
━━━━━━━━━━━━━━━━━━━━━━━━━━

\`/status\`
Show comprehensive system status including:
  • CPU, memory, disk usage with progress bars
  • Temperature and battery
  • Network and Tailscale status
  • NixOS generation

\`/status quick\`
Quick overview with essential metrics only.

\`/status detailed\`
Detailed status including service health.

\`/health\`
Run full deployment health check with 11 checks.

\`/metrics [category]\`
View system metrics. Categories:
  \`cpu\` \`memory\` \`disk\` \`network\` \`services\` \`tailscale\` \`prometheus\`

\`/log [n] [unit]\`
Show last n journal lines (default 50).
Example: \`/log 100 nginx\`

\`/processes\`
List running GUI processes.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Select another category or_ \`/help\` _for main menu_"

  send_inline_keyboard "$chat" "$out" \
    "◀ Main Menu:help_main" \
    "🚀 Deployment:help_deployment" \
    "🖥 Desktop:help_desktop" \
    "🔧 System:help_system"
}

_help_desktop() {
  local out="🖥 *Desktop Commands*
━━━━━━━━━━━━━━━━━━━━━━━━━━

\`/open <app>\`
Smart launcher with fuzzy matching:
  • URLs: \`/open github.com\`
  • Folders: \`/open downloads\`
  • Apps: \`/open firefox\` or \`/open terminal\`

\`/screenshot\`
Capture desktop screenshot and send as photo.

\`/clipboard\` / \`/clipboard set <text>\`
Read or set clipboard content.

\`/volume\` / \`/volume <N>\` / \`/mute\` / \`/unmute\`
Audio control (0-150%).

\`/brightness\` / \`/brightness <N>\`
Backlight control (0-100%).

\`/notify <msg>\`
Send a desktop notification.

\`/windows\`
List all open windows with workspace info.

\`/focus <app>\` / \`/close <app>\`
Focus or close a window by title.

\`/workspace next\` / \`prev\` / \`<N>\`
Switch GNOME workspaces.

\`/lock\` \`/logout\` \`/suspend\` \`/hibernate\`
Power management commands.

\`/monitoroff\` \`/monitoron\`
Control display power.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Select another category or_ \`/help\` _for main menu_"

  send_inline_keyboard "$chat" "$out" \
    "◀ Main Menu:help_main" \
    "🚀 Deployment:help_deployment" \
    "📊 Monitoring:help_monitoring" \
    "🔧 System:help_system"
}

_help_system() {
  local out="🔧 *System Commands*
━━━━━━━━━━━━━━━━━━━━━━━━━━

\`/run <cmd>\`
Execute arbitrary shell command on the host.
  ⚠️ Requires admin role.

\`/git <cmd>\`
Run git command in the infra repo.
Example: \`/git status\`, \`/git log --oneline\`

\`/nix <cmd>\`
Run arbitrary nix command.
Example: \`/nix flake update\`, \`/nix store gc\`

\`/gc\`
Garbage collect the Nix store to free space.
  ⚠️ Requires admin role.

\`/store\`
Show Nix store status (size, derivations).

\`/doctor\`
Full repository health check.

\`/scan\` / \`/security\`
Security scan of the system.

\`/backup\`
Show SOPS secrets backup status.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Select another category or_ \`/help\` _for main menu_"

  send_inline_keyboard "$chat" "$out" \
    "◀ Main Menu:help_main" \
    "🚀 Deployment:help_deployment" \
    "📊 Monitoring:help_monitoring" \
    "🖥 Desktop:help_desktop"
}

_help_gitlab() {
  local out="📦 *GitLab Commands*
━━━━━━━━━━━━━━━━━━━━━━━━━━

\`/gitlab status\`
Show project info and latest pipeline status.

\`/gitlab pipelines\`
List recent pipelines with status.

\`/gitlab trigger\`
Trigger a new pipeline on main branch.
  ⚠️ Requires admin role.

\`/gitlab mr\`
List open merge requests.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Select another category or_ \`/help\` _for main menu_"

  send_inline_keyboard "$chat" "$out" \
    "◀ Main Menu:help_main" \
    "🚀 Deployment:help_deployment" \
    "🐙 GitHub:help_github"
}

_help_github() {
  local out="🐙 *GitHub Commands*
━━━━━━━━━━━━━━━━━━━━━━━━━━

\`/github status\`
Show repository info and latest workflow run.

\`/github actions\`
List recent workflow runs with status.

\`/github issues\`
List open issues.

\`/github prs\`
List open pull requests.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Select another category or_ \`/help\` _for main menu_"

  send_inline_keyboard "$chat" "$out" \
    "◀ Main Menu:help_main" \
    "📦 GitLab:help_gitlab" \
    "🔧 System:help_system"
}

register_command "help" "_cmd_help" "📖 Show command menu and help"
# /menu is registered by menu.sh — this line intentionally omitted to avoid override
