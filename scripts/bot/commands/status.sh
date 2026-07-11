#!/usr/bin/env bash
# commands/status.sh — /status — comprehensive system snapshot with visual indicators
##############################################################################

_cmd_status() {
  local chat="$1" args="$2"
  send_typing "$chat"

  local subcmd="${args%% *}"

  case "$subcmd" in
    quick|q)
      _status_quick "$chat"
      ;;
    detailed|d)
      _status_detailed "$chat"
      ;;
    services|svc)
      _status_services "$chat"
      ;;
    *)
      _status_full "$chat"
      ;;
  esac
}

_status_quick() {
  local cpu_idle=$(top -bn1 2>/dev/null | awk '/^%Cpu/{print $8}' || echo "0")
  local cpu_used=$(awk "BEGIN{printf \"%.0f\", 100 - ${cpu_idle:-0}}" 2>/dev/null || echo "?")
  local mem_pct=$(free -m 2>/dev/null | awk '/^Mem:/{printf "%.0f", ($3/$2)*100}')
  local disk_pct=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
  local uptime_str=$(uptime 2>/dev/null | sed 's/.*up //; s/,.*//')
  local ts_ip=$(tailscale ip -4 2>/dev/null || echo "disconnected")
  local gen=$(nix_current_generation 2>/dev/null || echo "?")

  local out="📊 *${HOST}* — Quick Status
━━━━━━━━━━━━━━━━━━━━━━━━━━

💻 *CPU:*    \`$(progress_bar "${cpu_used}" 100)\`
🧠 *Memory:* \`$(progress_bar "${mem_pct}" 100)\`
💾 *Disk:*   \`$(progress_bar "${disk_pct}" 100)\`

⏱ *Uptime:* \`${uptime_str}\`
📡 *VPN:*    \`${ts_ip}\`
🧬 *Gen:*    \`${gen}\`

━━━━━━━━━━━━━━━━━━━━━━━━━━
Run \`/status detailed\` for more"

  send_msg "$chat" "$out"
}

_status_full() {
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  # CPU
  local cpu_idle=$(top -bn1 2>/dev/null | awk '/^%Cpu/{print $8}' || echo "0")
  local cpu_used=$(awk "BEGIN{printf \"%.0f\", 100 - ${cpu_idle:-0}}" 2>/dev/null || echo "?")
  local cpu_cores=$(nproc 2>/dev/null || echo "?")

  # Memory
  local mem_used=$(free -m 2>/dev/null | awk '/^Mem:/{print $3}')
  local mem_total=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
  local mem_pct=0
  [[ "$mem_total" -gt 0 ]] 2>/dev/null && mem_pct=$(( mem_used * 100 / mem_total ))

  # Swap
  local swap_used=$(free -m 2>/dev/null | awk '/^Swap:/{print $3}')
  local swap_total=$(free -m 2>/dev/null | awk '/^Swap:/{print $2}')
  local swap_pct=0
  [[ "$swap_total" -gt 0 ]] 2>/dev/null && swap_pct=$(( swap_used * 100 / swap_total ))

  # Disk
  local disk_used_pct=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')

  # Temperature
  local temp_str=""
  local temp_file="/sys/class/thermal/thermal_zone0/temp"
  if [[ -f "$temp_file" ]]; then
    local raw=$(cat "$temp_file" 2>/dev/null)
    local temp_c=$(( raw / 1000 ))
    temp_str="🌡 *Temp:*     \`$(progress_bar "${temp_c}" 100 12) \`${temp_c}°C"
  fi

  # Battery
  local battery_str=""
  local bat="/sys/class/power_supply/BAT0"
  if [[ -d "$bat" ]]; then
    local cap=$(cat "$bat/capacity" 2>/dev/null || echo "?")
    local bstatus=$(cat "$bat/status" 2>/dev/null || echo "?")
    battery_str="🔋 *Battery:*  \`$(progress_bar "${cap}" 100 12) \`${cap}% (${bstatus})"
  fi

  # Network
  local net_info=$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2 " on " $NF}' | head -2 | tr '\n' ', ' | sed 's/, $//')

  # Tailscale
  local ts_ip="disconnected"
  if command -v tailscale >/dev/null 2>&1; then
    ts_ip=$(tailscale ip -4 2>/dev/null || echo "disconnected")
  fi

  # Session
  local session_str="none"
  if pgrep -u "${DEFAULT_USER}" gnome-shell >/dev/null 2>&1; then
    session_str="GNOME (Wayland)"
  elif [[ -n "${XDG_SESSION_TYPE:-}" ]]; then
    session_str="${XDG_SESSION_TYPE^^}"
  fi

  local out="🛰 *${HOST}* — System Status
${sep}

💻 *CPU:*      \`$(progress_bar "${cpu_used}" 100)\` (${cpu_cores} cores)
🧠 *Memory:*   \`$(progress_bar "${mem_pct}" 100)\` (${mem_used}M / ${mem_total}M)
💾 *Disk (/):* \`$(progress_bar "${disk_used_pct}" 100)\`"

  # Swap (only if present)
  if [[ "$swap_total" -gt 0 ]] 2>/dev/null; then
    out+="
🔄 *Swap:*     \`$(progress_bar "${swap_pct}" 100)\` (${swap_used}M / ${swap_total}M)"
  fi

  # Temperature and Battery
  [[ -n "$temp_str" ]] && out+="
${temp_str}"
  [[ -n "$battery_str" ]] && out+="
${battery_str}"

  out+="
${sep}
🧬 *Kernel:*   \`$(uname -srm 2>/dev/null || echo "unknown")\`
⏱ *Uptime:*   \`$(uptime 2>/dev/null | sed 's/.*up //; s/,.*//')\`
📈 *Load:*     \`$(uptime 2>/dev/null | awk -F'load average: ' '{print $2}')\`
🧬 *Gen:*      \`$(nix_current_generation 2>/dev/null || echo "unknown")\`
🌐 *Network:*  \`${net_info:-unknown}\`
📡 *VPN:*      \`${ts_ip}\`
🖥 *Session:*  \`${session_str}\`
${sep}
_run \`/health\` for full diagnostics_
_run \`/metrics\` for detailed metrics_"

  send_msg "$chat" "$out"
}

_status_detailed() {
  _status_full "$chat"
  _status_services "$chat"
}

_status_services() {
  local sep="━━━━━━━━━━━━━━━━━━━━━━"
  local out="
🔧 *Service Status*
${sep}
"

  local services=("tailscaled" "nginx" "prometheus" "grafana" "loki" "sshd" "network-manager" "ivali-bot")
  for svc in "${services[@]}"; do
    local status
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      status="🟢 active"
    elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
      status="🟡 enabled"
    else
      status="⚪ inactive"
    fi
    out+="*${svc}:* ${status}
"
  done

  # Failed units
  local failed_count=$(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)
  if [[ "$failed_count" -gt 0 ]]; then
    out+="
⚠️ *${failed_count} failed units:*
\`\`\`
$(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | head -5)
\`\`\`
"
  fi

  send_msg "$chat" "$out"
}

register_command "status" "_cmd_status" "📊 System snapshot (quick/detailed/services)"
