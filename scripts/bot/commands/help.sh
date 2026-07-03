#!/usr/bin/env bash
# commands/help.sh — /help — Show command menu with inline suggestions
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
    *)
      _help_main "$chat"
      ;;
  esac
}

_help_main() {
  local out="🛰 *${HOST}* — Control Plane
━━━━━━━━━━━━━━━━━━━━━━━━━━

_NixOS GitOps bot · long-poll session active_
━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 *Deployment*
\`/deploy\`       Apply config — \`nixos-rebuild switch\`
\`/update\`       Pull → flake update → push
\`/rollback\`     Revert to previous generation

📊 *Monitoring*
\`/status\`       System snapshot (CPU, memory, disk, temp…)
\`/health\`       Full deployment health check
\`/metrics\`      View system metrics (cpu/memory/disk/network)
\`/log [n] [unit]\` Last n journal lines _(default 50)_
\`/processes\`    List running GUI processes

🧹 *Maintenance*
\`/gc\`           Garbage‑collect the nix store
\`/reboot\`       Reboot the host _(20s grace period)_
\`/shutdown\`     Power off the host _(20s grace period)_
\`/cancel\`       Abort a pending reboot/shutdown

🖥 *Applications*
\`/open <app>\`   Launch any application, URL, or folder
\`/firefox\`      Open Firefox
\`/apps\`         List discovered applications
\`/run <cmd>\`    Execute a shell command

🎛 *Desktop*
\`/screenshot\`   Capture desktop screenshot
\`/clipboard\`    Read/set clipboard
\`/volume\`       Volume info / set / mute / unmute
\`/brightness\`   Brightness info / set
\`/notify <msg>\` Send a desktop notification
\`/windows\`      List open windows
\`/focus <app>\`  Focus a window by title
\`/close <app>\`  Close a window by title
\`/workspace\`    Switch workspaces (next/prev/N)
\`/lock\`         Lock screen
\`/logout\`       Log out of GNOME
\`/suspend\`      Suspend to RAM
\`/hibernate\`    Hibernate to disk
\`/monitor-off\`  Turn displays off
\`/monitor-on\`   Wake displays

🔧 *Raw Access*
\`/git <cmd>\`    Run git in the infra repo
\`/nix <cmd>\`    Run an arbitrary nix command

📦 *GitLab*
\`/gitlab status\`     Project + latest pipeline
\`/gitlab pipelines\`  Recent pipelines
\`/gitlab trigger\`    Trigger a pipeline
\`/gitlab mr\`         List merge requests

ℹ️ \`/help\`  \`/menu\`  Show this menu
━━━━━━━━━━━━━━━━━━━━━━━━━━
_Run \`/help <category>\` for detailed help_
_Example: \`/help deployment\` or \`/help desktop\`_
━━━━━━━━━━━━━━━━━━━━━━━━━━
🔒 Authorized chat only · replies may be split across messages"

  send_keyboard "$chat" "$out" "/status" "/health" "/metrics" "/deploy" "/rollback" "/help"
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
• Requires admin role

\`/update\`
Update flake inputs and push changes.
This will:
• Pull latest changes from Git
• Run \`nix flake update\`
• Commit and push changes
• Requires admin role

\`/rollback\`
Revert to the previous NixOS generation.
This will:
• Switch to the previous generation
• Can be undone with \`/deploy\`
• Requires admin role

\`/generations\`
List all NixOS generations with timestamps.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Run \`/help\` to see all categories_"

  send_msg "$chat" "$out"
}

_help_monitoring() {
  local out="📊 *Monitoring Commands*
━━━━━━━━━━━━━━━━━━━━━━━━━━

\`/status\`
Show comprehensive system status including:
• CPU, memory, disk usage
• Temperature and battery
• Network and Tailscale status
• NixOS generation

\`/status quick\`
Quick overview with essential metrics only.

\`/status detailed\`
Detailed status including service health.

\`/health\`
Run full deployment health check with 11 checks:
• NixOS generation
• Systemd services
• Disk and memory usage
• Network connectivity
• Tailscale status
• Nginx, SSH, Prometheus, Grafana, Loki

\`/metrics\`
View system metrics from Prometheus.
Subcommands: \`cpu\`, \`memory\`, \`disk\`, \`network\`, \`services\`, \`tailscale\`, \`prometheus\`

\`/log [n] [unit]\`
Show last n journal lines (default 50).
Example: \`/log 100 nginx\`

\`/processes\`
List running GUI processes.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Run \`/help\` to see all categories_"

  send_msg "$chat" "$out"
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

\`/clipboard\`
Read current clipboard content.

\`/clipboard set <text>\`
Set clipboard content.

\`/volume\`
Show current volume level.

\`/volume <N>\`
Set volume to N% (0-150).

\`/mute\` / \`/unmute\`
Mute/unmute audio.

\`/brightness\`
Show current brightness level.

\`/brightness <N>\`
Set brightness to N% (0-100).

\`/notify <msg>\`
Send a desktop notification.

\`/windows\`
List all open windows.

\`/focus <app>\`
Focus a window by title.

\`/close <app>\`
Close a window by title.

\`/workspace next\` / \`prev\` / \`<N>\`
Switch workspaces.

\`/lock\` / \`/logout\` / \`/suspend\` / \`/hibernate\`
Power management commands.

\`/monitor-off\` / \`/monitor-on\`
Control display power.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Run \`/help\` to see all categories_"

  send_msg "$chat" "$out"
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

\`/scan\`
Security scan of the system.

\`/security\`
Security scan report with details.

\`/backup\`
Show SOPS secrets backup status.

━━━━━━━━━━━━━━━━━━━━━━━━━━
_Run \`/help\` to see all categories_"

  send_msg "$chat" "$out"
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
_Run \`/help\` to see all categories_"

  send_msg "$chat" "$out"
}

register_command "help" "_cmd_help" "📖 Show command menu and help"
register_command "menu" "_cmd_help" "📖 Show command menu"
