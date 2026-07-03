#!/usr/bin/env bash
# commands/windows.sh — /windows, /focus <app>, /close <app> — window management
# Uses GNOME Shell DBus API (works natively on Wayland)
##############################################################################

_cmd_windows() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  # Query GNOME Shell for open windows via DBus Eval
  local result
  result="$(gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    'global.get_window_actors().map(a => { let w = a.meta_window; return w.get_title() + " [" + w.get_wm_class() + "] (pid:" + w.get_pid() + ")"; }).join("\n")' 2>/dev/null)" || true

  # Extract the string from DBus response: ('result', [uint32 0],)
  local wins
  wins="$(echo "$result" | sed "s/^('\\(.*\\)',.*$/\1/" | sed 's/\\n/\n/g')"

  if [[ -z "$wins" || "$wins" == "''" ]]; then
    send_msg "$chat" "🪟 No open windows detected."
    return
  fi

  local out="🪟 *Open Windows*
${sep}
\`\`\`
${wins}
\`\`\`"

  send_long "$chat" "$out"
}

_cmd_focus() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/focus <window title>\`
_Focus a window by title._
_Example:_ \`/focus Firefox\`"
    return
  fi

  # Use GNOME Shell DBus to find and activate window
  local js="let wins = global.get_window_actors(); let found = false; for (let a of wins) { let w = a.meta_window; if (w.get_title().toLowerCase().includes('${args,,}'.toLowerCase())) { w.activate(global.get_current_time()); found = true; break; } }; found ? 'focused' : 'not_found'"

  local result
  result="$(gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    "$js" 2>/dev/null)" || true

  if echo "$result" | grep -q "focused"; then
    send_msg "$chat" "🪟 Focused: \`${args}\`"
  else
    send_msg "$chat" "❌ Window \`${args}\` not found."
  fi
}

_cmd_close() {
  local chat="$1" args="$2"

  if [[ -z "$args" ]]; then
    send_msg "$chat" "🔧 *Usage:* \`/close <window title>\`
_Close a window by title._
_Example:_ \`/close Firefox\`"
    return
  fi

  # Use GNOME Shell DBus to find and close window
  local js="let wins = global.get_window_actors(); let found = false; for (let a of wins) { let w = a.meta_window; if (w.get_title().toLowerCase().includes('${args,,}'.toLowerCase())) { w.delete(global.get_current_time()); found = true; break; } }; found ? 'closed' : 'not_found'"

  local result
  result="$(gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    "$js" 2>/dev/null)" || true

  if echo "$result" | grep -q "closed"; then
    send_msg "$chat" "🪟 Closed: \`${args}\`"
  else
    send_msg "$chat" "❌ Window \`${args}\` not found."
  fi
}

register_command "windows" "_cmd_windows" "🪟 List open windows"
register_command "focus" "_cmd_focus" "🪟 Focus a window"
register_command "close" "_cmd_close" "🪟 Close a window"
