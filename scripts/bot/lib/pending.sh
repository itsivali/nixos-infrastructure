#!/usr/bin/env bash
# lib/pending.sh — Pending action tracking for reboot/shutdown
#
# Dependencies: lib/core.sh (log), lib/telegram.sh (send_msg)
# Provides:     pending_set, pending_cancel, pending_status
##############################################################################

# Global state — the PID of a background reboot/shutdown action
_PENDING_PID=""

# Launch a background action and track its PID.
# Usage: pending_set bash -c 'sleep 20 && systemctl reboot'
pending_set() {
  "$@" 2>/dev/null &
  _PENDING_PID=$!
}

# Cancel a pending action. Returns 0 if cancelled, 1 if nothing pending.
# Usage: pending_cancel && send_msg "$chat" "🛑 Cancelled."
pending_cancel() {
  if [[ -n "$_PENDING_PID" ]] && kill -0 "$_PENDING_PID" 2>/dev/null; then
    kill "$_PENDING_PID" 2>/dev/null || true
    _PENDING_PID=""
    return 0
  fi
  _PENDING_PID=""
  return 1
}

# Check if a pending action is running.
# Usage: if pending_status; then echo "pending"; fi
pending_status() {
  if [[ -n "$_PENDING_PID" ]] && kill -0 "$_PENDING_PID" 2>/dev/null; then
    return 0
  fi
  return 1
}
