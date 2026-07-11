#!/usr/bin/env bash
# commands/metrics.sh — /metrics — View system metrics from Prometheus
##############################################################################

_cmd_metrics() {
  local chat="$1" args="$2"
  send_typing "$chat"

  local subcmd="${args%% *}"
  local rest="${args#* }"

  case "$subcmd" in
    cpu|cpuUsage)
      _metrics_cpu "$chat"
      ;;
    memory|mem|ram)
      _metrics_memory "$chat"
      ;;
    disk|storage)
      _metrics_disk "$chat"
      ;;
    network|net)
      _metrics_network "$chat"
      ;;
    services|svc)
      _metrics_services "$chat"
      ;;
    tailscale|ts)
      _metrics_tailscale "$chat"
      ;;
    prometheus|prom)
      _metrics_prometheus "$chat"
      ;;
    overview|summary|"")
      _metrics_overview "$chat"
      ;;
    *)
      send_msg "$chat" "📊 *Metrics Viewer*

Usage: \`/metrics [category]\`

*Categories:*
• \`cpu\` — CPU usage over time
• \`memory\` — Memory utilization
• \`disk\` — Disk I/O and usage
• \`network\` — Network traffic
• \`services\` — Service health
• \`tailscale\` — Tailscale status
• \`prometheus\` — Prometheus health
• \`overview\` — Full system overview

*Examples:*
• \`/metrics\` — Show overview
• \`/metrics cpu\` — CPU details
• \`/metrics memory\` — Memory details"
      ;;
  esac
}

_metrics_overview() {
  local chat="$1"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  # CPU
  local cpu_idle
  cpu_idle=$(top -bn1 2>/dev/null | awk '/^%Cpu/{print $8}' || echo "0")
  local cpu_used=$(awk "BEGIN{printf \"%.1f\", 100 - ${cpu_idle:-0}}" 2>/dev/null || echo "0")
  local cpu_cores=$(nproc 2>/dev/null || echo "?")

  # Memory
  local mem_pct=$(free -m 2>/dev/null | awk '/^Mem:/{printf "%.0f", ($3/$2)*100}')
  local mem_used=$(free -m 2>/dev/null | awk '/^Mem:/{print $3}')
  local mem_total=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')

  # Disk
  local disk_pct=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
  local disk_used=$(df -h / 2>/dev/null | awk 'NR==2{print $3}')
  local disk_total=$(df -h / 2>/dev/null | awk 'NR==2{print $2}')

  # Load
  local load_info
  load_info=$(uptime 2>/dev/null | awk -F'load average: ' '{print $2}')

  # Uptime
  local uptime_info
  uptime_info=$(uptime 2>/dev/null | sed 's/.*up //; s/,.*//')

  # Network
  local net_info
  net_info=$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2 " on " $NF}' | head -2 | tr '\n' ', ' | sed 's/, $//')

  # Tailscale
  local ts_status_str="not installed"
  if command -v tailscale >/dev/null 2>&1; then
    local ts_ip
    ts_ip=$(tailscale ip -4 2>/dev/null || echo "disconnected")
    local ts_online
    ts_online=$(tailscale status --json 2>/dev/null | jq -r '.Self.Online // false' 2>/dev/null || echo "false")
    if [[ "$ts_online" == "true" ]]; then
      ts_status_str="🟢 ${ts_ip}"
    else
      ts_status_str="🔴 offline"
    fi
  fi

  local out="📊 *${HOST}* — System Metrics
${sep}

💻 *CPU:*    \`$(progress_bar "${cpu_used%%.*}" 100)\` (${cpu_used}%, ${cpu_cores} cores)
🧠 *Memory:* \`$(progress_bar "${mem_pct}" 100)\` (${mem_used}M/${mem_total}M)
💾 *Disk:*   \`$(progress_bar "${disk_pct}" 100)\` (${disk_used}/${disk_total})

📈 *Load:*  \`${load_info:-unknown}\`
⏱ *Uptime:* \`${uptime_info:-unknown}\`
🌐 *Net:*   \`${net_info:-unknown}\`
📡 *VPN:*   \`${ts_status_str}\`
${sep}
Run \`/metrics cpu\` for detailed CPU info"

  send_msg "$chat" "$out"
}

_metrics_cpu() {
  local chat="$1"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  # CPU usage
  local cpu_idle
  cpu_idle=$(top -bn1 2>/dev/null | awk '/^%Cpu/{print $8}' || echo "0")
  local cpu_used=$(awk "BEGIN{printf \"%.1f\", 100 - ${cpu_idle:-0}}" 2>/dev/null || echo "0")
  local cpu_int=${cpu_used%%.*}

  # CPU cores
  local cores=$(nproc 2>/dev/null || echo "?")

  # CPU frequency
  local freq_str="unknown"
  local freq_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
  if [[ -f "$freq_file" ]]; then
    local freq=$(cat "$freq_file" 2>/dev/null)
    local freq_mhz=$(( freq / 1000 ))
    freq_str="$(awk "BEGIN{printf \"%.2f\", $freq_mhz/1000}") GHz"
  fi

  # CPU temperature
  local temp_str="unknown"
  local temp_file="/sys/class/thermal/thermal_zone0/temp"
  if [[ -f "$temp_file" ]]; then
    local temp=$(cat "$temp_file" 2>/dev/null)
    temp_str="$(( temp / 1000 ))°C"
  fi

  local out="💻 *${HOST}* — CPU Metrics
${sep}

*Usage:* \`$(progress_bar "${cpu_int}" 100)\` (${cpu_used}%)
*Cores:* ${cores}
*Freq:*  ${freq_str}
*Temp:*  ${temp_str}

${sep}
*Top processes by CPU:*
\`\`\`
$(ps aux --sort=-%cpu 2>/dev/null | head -6 | awk '{printf "%-5s %-6s %s\n", $3"%", $2, $11}')
\`\`\`"

  send_msg "$chat" "$out"
}

_metrics_memory() {
  local chat="$1"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  # Memory usage
  local mem_used=$(free -m 2>/dev/null | awk '/^Mem:/{print $3}')
  local mem_total=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
  local mem_available=$(free -m 2>/dev/null | awk '/^Mem:/{print $7}')
  local mem_pct=0
  [[ "$mem_total" -gt 0 ]] 2>/dev/null && mem_pct=$(( mem_used * 100 / mem_total ))

  # Swap
  local swap_used=$(free -m 2>/dev/null | awk '/^Swap:/{print $3}')
  local swap_total=$(free -m 2>/dev/null | awk '/^Swap:/{print $2}')
  local swap_pct=0
  [[ "$swap_total" -gt 0 ]] 2>/dev/null && swap_pct=$(( swap_used * 100 / swap_total ))

  local out="🧠 *${HOST}* — Memory Metrics
${sep}

*RAM:* \`$(progress_bar "${mem_pct}" 100)\`
  Used: ${mem_used}MB / ${mem_total}MB
  Available: ${mem_available}MB"

  # Swap (only if present)
  if [[ "$swap_total" -gt 0 ]] 2>/dev/null; then
    out+="
${sep}
*Swap:* \`$(progress_bar "${swap_pct}" 100)\`
  Used: ${swap_used}MB / ${swap_total}MB"
  fi

  out+="
${sep}
*Top processes by memory:*
\`\`\`
$(ps aux --sort=-%mem 2>/dev/null | head -6 | awk '{printf "%-5s %-6s %s\n", $4"%", $2, $11}')
\`\`\`"

  send_msg "$chat" "$out"
}

_metrics_disk() {
  local chat="$1"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  # Disk usage
  local disk_used_pct=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
  local disk_used=$(df -h / 2>/dev/null | awk 'NR==2{print $3}')
  local disk_total=$(df -h / 2>/dev/null | awk 'NR==2{print $2}')
  local disk_avail=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')

  local out="💾 *${HOST}* — Disk Metrics
${sep}

*Root filesystem:*
\`$(progress_bar "${disk_used_pct}" 100)\`
  Used: ${disk_used} / ${disk_total}
  Free: ${disk_avail}
${sep}"

  # Disk I/O
  local io_info
  io_info=$(iostat -d -h 2>/dev/null | head -10 || echo "iostat not available")
  if [[ "$io_info" != "iostat not available" ]]; then
    out+="
*Disk I/O:*
\`\`\`
${io_info}
\`\`\`
"
  fi

  # Nix store size
  local nix_size=$(du -sh /nix/store 2>/dev/null | cut -f1 || echo "unknown")
  out+="
*Nix Store:* ${nix_size}
"

  # Inodes
  local inode_info
  inode_info=$(df -i / 2>/dev/null | tail -1 | awk '{print $5 " used"}')
  out+="*Inodes:* ${inode_info:-unknown}
"

  send_msg "$chat" "$out"
}

_metrics_network() {
  local chat="$1"
  local out="🌐 *Network Metrics*
━━━━━━━━━━━━━━━━━━━━━━━━━━

"

  # Network interfaces
  local net_info
  net_info=$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2 " on " $NF}' | tr '\n' '\n')
  out+="*Interfaces:*
\`\`\`
${net_info:-Network info unavailable}
\`\`\`
"

  # Network stats
  local net_stats
  net_stats=$(cat /proc/net/dev 2>/dev/null | tail -n +3 | awk '{print $1, "RX:"$2, "TX:"$10}' | head -5)
  if [[ -n "$net_stats" ]]; then
    out+="*Traffic:*
\`\`\`
${net_stats}
\`\`\`
"
  fi

  # DNS
  local dns_info
  dns_info=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | head -3 | awk '{print $2}' | tr '\n' '\n')
  if [[ -n "$dns_info" ]]; then
    out+="*DNS Servers:*
\`\`\`
${dns_info}
\`\`\`
"
  fi

  # Tailscale
  if command -v tailscale >/dev/null 2>&1; then
    local ts_status
    ts_status=$(tailscale status 2>/dev/null | head -5)
    if [[ -n "$ts_status" ]]; then
      out+="*Tailscale:*
\`\`\`
${ts_status}
\`\`\`
"
    fi
  fi

  send_msg "$chat" "$out"
}

_metrics_services() {
  local chat="$1"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"
  local out="🔧 *${HOST}* — Service Metrics
${sep}
"

  # Critical services
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
  local failed_count
  failed_count=$(systemctl list-units --failed --no-legend --no-pager 2>/dev/null | wc -l)
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

_metrics_tailscale() {
  local chat="$1"

  if ! command -v tailscale >/dev/null 2>&1; then
    send_msg "$chat" "❌ Tailscale is not installed"
    return
  fi

  local out="📡 *Tailscale Metrics*
━━━━━━━━━━━━━━━━━━━━━━━━━━

"

  # Tailscale status
  local ts_json
  ts_json=$(tailscale status --json 2>/dev/null || echo "{}")

  local ts_ip=$(echo "$ts_json" | jq -r '.Self.TailscaleIPs[0] // "unknown"' 2>/dev/null)
  local ts_online=$(echo "$ts_json" | jq -r '.Self.Online // false' 2>/dev/null)
  local ts_host=$(echo "$ts_json" | jq -r '.Self.HostName // "unknown"' 2>/dev/null)
  local ts_dns=$(echo "$ts_json" | jq -r '.Self.DNSName // "unknown"' 2>/dev/null)

  out+="*IP:* ${ts_ip}
*Host:* ${ts_host}
*DNS:* ${ts_dns}
*Online:* $(if [[ "$ts_online" == "true" ]]; then echo "🟢 Yes"; else echo "🔴 No"; fi)
"

  # Key expiry
  local ts_expiry=$(echo "$ts_json" | jq -r '.Self.KeyExpiry // "none"' 2>/dev/null)
  if [[ "$ts_expiry" != "none" && "$ts_expiry" != "null" ]]; then
    local expiry_epoch=$(date -d "$ts_expiry" +%s 2>/dev/null || echo "0")
    local now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    out+="*Key Expiry:* ${ts_expiry} (${days_left} days)
"
  else
    out+="*Key Expiry:* No expiry
"
  fi

  # Peers
  local peer_count=$(echo "$ts_json" | jq -r '.Peer | length' 2>/dev/null || echo "0")
  out+="
*Peers:* ${peer_count} connected
"

  # Connected peers
  local peers=$(echo "$ts_json" | jq -r '.Peer | to_entries[] | select(.value.Online == true) | .value.HostName' 2>/dev/null | head -5)
  if [[ -n "$peers" ]]; then
    out+="*Connected:*
\`\`\`
${peers}
\`\`\`
"
  fi

  send_msg "$chat" "$out"
}

_metrics_prometheus() {
  local chat="$1"
  local out="📈 *Prometheus Metrics*
━━━━━━━━━━━━━━━━━━━━━━━━━━

"

  # Check if Prometheus is running
  if ! systemctl is-active --quiet prometheus 2>/dev/null; then
    out+="❌ *Prometheus is not running*

Enable with: \`ivali.observability.enable = true\`
"
    send_msg "$chat" "$out"
    return
  fi

  # Prometheus health
  local health=$(curl -s http://127.0.0.1:9090/-/healthy 2>/dev/null || echo "unreachable")
  out+="*Health:* ${health}
"

  # Prometheus config
  local config=$(curl -s http://127.0.0.1:9090/api/v1/status/config 2>/dev/null | jq -r '.data.yaml // "unavailable"' 2>/dev/null || echo "unavailable")
  if [[ "$config" != "unavailable" ]]; then
    out+="
*Configuration:*
\`\`\`
${config:0:500}
\`\`\`
"
  fi

  # Active targets
  local targets=$(curl -s http://127.0.0.1:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
  out+="*Active Targets:* ${targets}
"

  # Alert rules
  local rules=$(curl -s http://127.0.0.1:9090/api/v1/rules 2>/dev/null | jq -r '.data.groups | length' 2>/dev/null || echo "0")
  out+="*Rule Groups:* ${rules}
"

  # Storage
  local storage=$(curl -s http://127.0.0.1:9090/api/v1/status/tsdb 2>/dev/null | jq -r '.data.storageStats.numSeries // "unknown"' 2>/dev/null || echo "unknown")
  out+="*Active Series:* ${storage}
"

  send_msg "$chat" "$out"
}

register_command "metrics" "_cmd_metrics" "📈 View system metrics (cpu/memory/disk/network/services/tailscale/prometheus)"
register_command "m" "_cmd_metrics" "📈 View system metrics (shortcut)"
