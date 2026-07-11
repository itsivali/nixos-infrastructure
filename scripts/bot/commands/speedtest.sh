#!/usr/bin/env bash
# commands/speedtest.sh — /speedtest — network speed test
##############################################################################

_cmd_speedtest() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_typing "$chat"
  send_msg "$chat" "🌐 Running speed test..."

  local start_ms end_ms elapsed_ms download_speed ping_ms

  # Ping test (3 pings to 8.8.8.8)
  ping_ms=$(ping -c 3 -W 5 8.8.8.8 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "timeout")

  # Download speed test using a 10MB file from speedtest.tele2.net
  local test_url="http://speedtest.tele2.net/10MB.zip"
  start_ms=$(date +%s%N)
  curl -s -o /dev/null --max-time 30 "$test_url" 2>/dev/null
  end_ms=$(date +%s%N)

  elapsed_ms=$(( (end_ms - start_ms) / 1000000 ))

  if [[ "$elapsed_ms" -gt 0 ]]; then
    # 10MB = 80 megabits; speed in Mbps
    download_speed=$(awk "BEGIN{printf \"%.1f\", (80000 / ${elapsed_ms})}")
  else
    download_speed="error"
  fi

  # Format elapsed time
  local elapsed_str
  elapsed_str=$(format_duration $(( elapsed_ms / 1000 )))

  local out="🌐 *${HOST}* — Speed Test
${sep}

📥 *Download:* ${download_speed} Mbps
📡 *Ping:*     ${ping_ms} ms
⏱ *Duration:* ${elapsed_str}
🎯 *Test:*     10MB file from speedtest.tele2.net

${sep}"

  # Add network info
  local net_info
  net_info=$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2 " on " $NF}' | head -2 | tr '\n' ', ' | sed 's/, $//')
  out+="
*Interfaces:*
\`\`\`
${net_info:-unknown}
\`\`\`"

  send_long "$chat" "$out"
}

register_command "speedtest" "_cmd_speedtest" "🌐 Network speed test"
