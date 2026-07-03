#!/usr/bin/env bash
# commands/status.sh — /status — comprehensive system snapshot
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
  local out="📊 *Quick Status*
━━━━━━━━━━━━━━━━━━━━━━━━━━

"
  
  # CPU
  local cpu_idle=$(top -bn1 2>/dev/null | awk '/^%Cpu/{print $8}' || echo "0")
  local cpu_used=$(awk "BEGIN{printf \"%.0f\", 100 - ${cpu_idle:-0}}" 2>/dev/null || echo "?")
  out+="💻 *CPU:* ${cpu_used}%
"
  
  # Memory
  local mem_percent=$(free -m 2>/dev/null | awk '/^Mem:/{printf "%.0f", ($3/$2)*100}')
  out+="🧠 *Memory:* ${mem_percent}%
"
  
  # Disk
  local disk_percent=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
  out+="💾 *Disk:* ${disk_percent}%
"
  
  # Uptime
  local uptime=$(uptime 2>/dev/null | sed 's/.*up //; s/,.*//')
  out+="⏱ *Uptime:* ${uptime}
"
  
  # Tailscale
  if command -v tailscale >/dev/null 2>&1; then
    local ts_ip=$(tailscale ip -4 2>/dev/null || echo "disconnected")
    out+="📡 *VPN:* ${ts_ip}
"
  fi
  
  # Generation
  local gen=$(nix_current_generation 2>/dev/null || echo "?")
  out+="🧬 *Gen:* ${gen}
"
  
  out+="
━━━━━━━━━━━━━━━━━━━━━━━━━━
Run \`/status detailed\` for more"
  
  send_msg "$chat" "$out"
}

_status_full() {
  local out="🛰 *${HOST}* — System Status
━━━━━━━━━━━━━━━━━━━━━━━━━━

"
  
  # Kernel
  out+="🧬 *Kernel:* \`$(uname -srm 2>/dev/null || echo "unknown")\`
"
  
  # Uptime
  out+="⏱ *Uptime:* \`$(uptime 2>/dev/null | sed 's/.*up //; s/,.*//')\`
"
  
  # Load
  out+="📈 *Load:* \`$(uptime 2>/dev/null | awk -F'load average: ' '{print $2}')\`
"
  
  # Memory
  local mem_info=$(free -h 2>/dev/null | awk '/^Mem:/{printf "%s / %s (%.0f%%)", $3, $2, ($3/$2)*100}')
  out+="🧠 *Memory:* \`${mem_info:-unknown}\`
"
  
  # Swap
  local swap_info=$(free -h 2>/dev/null | awk '/^Swap:/{print $3 " / " $2}')
  if [[ "$swap_info" != "0B / 0B" ]]; then
    out+="🔄 *Swap:* \`${swap_info}\`
"
  fi
  
  # CPU
  local cpu_idle=$(top -bn1 2>/dev/null | awk '/^%Cpu/{print $8}' || echo "0")
  local cpu_used=$(awk "BEGIN{printf \"%.0f\", 100 - ${cpu_idle:-0}}" 2>/dev/null || echo "?")
  local cpu_cores=$(nproc 2>/dev/null || echo "?")
  out+="💻 *CPU:* \`${cpu_used}% (${cpu_cores} cores)\`
"
  
  # Temperature
  local temp_file="/sys/class/thermal/thermal_zone0/temp"
  if [[ -f "$temp_file" ]]; then
    local temp=$(cat "$temp_file" 2>/dev/null)
    local temp_c=$(( temp / 1000 ))
    out+="🌡 *Temp:* \`${temp_c}°C\`
"
  fi
  
  # Battery
  local bat="/sys/class/power_supply/BAT0"
  if [[ -d "$bat" ]]; then
    local cap=$(cat "$bat/capacity" 2>/dev/null || echo "?")
    local status=$(cat "$bat/status" 2>/dev/null || echo "?")
    out+="🔋 *Battery:* \`${cap}% (${status})\`
"
  fi
  
  # Disk
  local disk_info=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
  out+="💾 *Disk (/):* \`${disk_info:-unknown}\`
"
  
  # Generation
  out+="🧬 *Generation:* \`$(nix_current_generation 2>/dev/null || echo "unknown")\`
"
  
  # Network
  local net_info=$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2 " on " $NF}' | tr '\n' ', ' | sed 's/, $//')
  out+="🌐 *Network:* \`${net_info:-unknown}\`
"
  
  # Tailscale
  if command -v tailscale >/dev/null 2>&1; then
    local ts_ip=$(tailscale ip -4 2>/dev/null || echo "disconnected")
    out+="📡 *VPN:* \`${ts_ip}\`
"
  fi
  
  # Session
  if [[ -n "${XDG_SESSION_TYPE:-}" ]]; then
    out+="🖥 *Session:* \`${XDG_SESSION_TYPE^^} (${DEFAULT_USER})\`
"
  fi
  
  out+="
━━━━━━━━━━━━━━━━━━━━━━━━━━
_run \`/health\` for full diagnostics_
_run \`/metrics\` for detailed metrics_"
  
  send_msg "$chat" "$out"
}

_status_detailed() {
  _status_full "$chat"
  
  # Add service status
  _status_services "$chat"
}

_status_services() {
  local out="
🔧 *Service Status*
━━━━━━━━━━━━━━━━━━━━━━━━━━

"
  
  local services=("tailscaled" "nginx" "prometheus" "grafana" "loki" "sshd" "network-manager")
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
