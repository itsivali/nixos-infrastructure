#!/usr/bin/env bash
# lib/system.sh — System information gathering
#
# Dependencies: coreutils, procps, nixos-rebuild
# Provides:     sys_* functions for comprehensive status reporting
##############################################################################

# CPU usage percentage (averaged across cores).
sys_cpu() {
  local idle
  idle="$(top -bn1 | awk '/^%Cpu/{print $8}' 2>/dev/null || echo "0")"
  # top shows "id" field, calculate used
  local used
  used="$(awk "BEGIN{printf \"%.0f\", 100 - ${idle:-0}}" 2>/dev/null || echo "?")"
  local cores
  cores="$(nproc 2>/dev/null || echo "?")"
  echo "${used}% (${cores} cores)"
}

# Memory usage.
sys_memory() {
  free -h 2>/dev/null | awk '/^Mem:/{print $3 " used / " $2 " total (" int($3/$2*100) "%)"}' || echo "unknown"
}

# Swap usage.
sys_swap() {
  free -h 2>/dev/null | awk '/^Swap:/{print $3 " used / " $2 " total"}' || echo "unknown"
}

# Disk usage for /.
sys_disk() {
  df -h / --output=size,used,avail,pcent 2>/dev/null | tail -1 | awk '{print $1 " total, " $2 " used, " $3 " free (" $4 ")"}' || echo "unknown"
}

# Battery status (if present).
sys_battery() {
  local bat="/sys/class/power_supply/BAT0"
  if [[ -d "$bat" ]]; then
    local cap status
    cap="$(cat "$bat/capacity" 2>/dev/null || echo "?")"
    status="$(cat "$bat/status" 2>/dev/null || echo "?")"
    echo "${cap}% (${status})"
  else
    echo "no battery"
  fi
}

# CPU temperature.
sys_temperature() {
  local temp_file="/sys/class/thermal/thermal_zone0/temp"
  if [[ -f "$temp_file" ]]; then
    local raw
    raw="$(cat "$temp_file" 2>/dev/null)"
    echo "$(( raw / 1000 ))°C"
  else
    echo "unknown"
  fi
}

# System uptime.
sys_uptime() {
  uptime 2>/dev/null | sed 's/.*up //; s/,.*//' || echo "unknown"
}

# Load average.
sys_load() {
  uptime 2>/dev/null | awk -F'load average: ' '{print $2}' || echo "unknown"
}

# Kernel version.
sys_kernel() {
  uname -srm 2>/dev/null || echo "unknown"
}

# NixOS generation.
sys_generation() {
  nix_current_generation
}

# Hostname.
sys_hostname() {
  hostname 2>/dev/null || echo "unknown"
}

# Network interfaces and IPs.
sys_network() {
  ip -4 addr show 2>/dev/null | awk '/inet /{print $2 " on " $NF}' | tr '\n' ', ' | sed 's/, $//' || echo "unknown"
}

# Tailscale status.
sys_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    local status
    status="$(tailscale status --json 2>/dev/null | jq -r '.Self.TailscaleIPs[0] // "disconnected"' 2>/dev/null || echo "unknown")"
    echo "Tailscale: ${status}"
  else
    echo "Tailscale: not installed"
  fi
}

sys_session() {
  if pgrep -u "${DEFAULT_USER}" Hyprland >/dev/null 2>&1; then
    echo "Hyprland (Wayland)"
  elif [[ -n "${XDG_SESSION_TYPE:-}" ]]; then
    echo "${XDG_SESSION_TYPE^^} session (${DEFAULT_USER})"
  else
    echo "no session"
  fi
}

# Generate a comprehensive status report.
# Usage: send_long "$chat" "$(sys_full_status)"
sys_full_status() {
  local sep="━━━━━━━━━━━━━━━━━━━━━━"
  local out="🛰 *${HOST}* — System Status
${sep}
🧬 *Kernel:*     \`$(sys_kernel)\`
⏱ *Uptime:*     \`$(sys_uptime)\`
📈 *Load avg:*   \`$(sys_load)\`
🧠 *Memory:*     \`$(sys_memory)\`
🔄 *Swap:*       \`$(sys_swap)\`
💻 *CPU:*        \`$(sys_cpu)\`
🌡 *Temp:*       \`$(sys_temperature)\`
🔋 *Battery:*    \`$(sys_battery)\`
💾 *Disk (/):*   \`$(sys_disk)\`
🧊 *NixGen:*     \`$(sys_generation)\`
🌐 *Network:*    \`$(sys_network)\`
📡 *VPN:*        \`$(sys_tailscale)\`
🖥 *Session:*    \`$(sys_session)\`
${sep}
Run \`/health\` for a full diagnostic."

  echo "$out"
}
