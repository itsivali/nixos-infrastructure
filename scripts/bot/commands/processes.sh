#!/usr/bin/env bash
# commands/processes.sh — /processes — list running GUI applications
# Uses GNOME Shell DBus API (works natively on Wayland)
##############################################################################

_cmd_processes() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  # Query GNOME Shell for window list with PIDs via DBus
  local result
  result="$(gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    'global.get_window_actors().map(a => { let w = a.meta_window; return w.get_title() + "|" + w.get_pid() + "|" + w.get_wm_class(); }).join("\n")' 2>/dev/null)" || true

  # Extract string from DBus response
  local wins
  wins="$(echo "$result" | sed "s/^('\\(.*\\)',.*$/\1/" | sed 's/\\n/\n/g')"

  if [[ -z "$wins" || "$wins" == "''" ]]; then
    send_msg "$chat" "📋 No GUI processes detected."
    return
  fi

  local out="📋 *GUI Processes*
${sep}
\`\`\`"
  out+=$(printf "%-30s %-8s %s\n" "WINDOW" "PID" "APP")
  out+=$'\n'"$(printf '%.0s-' {1..60})"

  while IFS='|' read -r title pid app; do
    [[ -z "$title" ]] && continue
    local display_title="${title:0:30}"
    local display_app="${app:0:16}"
    out+=$'\n'"$(printf "%-30s %-8s %s" "$display_title" "$pid" "$display_app")"
  done <<< "$wins"

  out+="
\`\`\`"

  send_long "$chat" "$out"
}

register_command "processes" "_cmd_processes" "📋 List GUI processes"
