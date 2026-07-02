#!/usr/bin/env bash
# lib/core.sh — Core helpers: logging, offset persistence, message age, command execution
#
# Dependencies: None
# Provides:     log, save_offset, is_recent, run_cmd, require_args, require_gitlab
##############################################################################

# Structured log output with ISO-8601 timestamp.
# Usage: log "message"
log() {
  echo "[$(date -Iseconds)] $*"
}

# Persist the Telegram update offset to disk atomically.
# Usage: save_offset 42
save_offset() {
  echo "$1" > "${OFFSET_FILE}.tmp" && mv "${OFFSET_FILE}.tmp" "$OFFSET_FILE"
}

# Returns 0 if the given unix timestamp is within MAX_AGE_SECONDS of now.
# Usage: if is_recent "$msg_date"; then ...
is_recent() {
  local msg_time="$1"
  local now
  now="$(date +%s)"
  (( now - msg_time <= MAX_AGE_SECONDS ))
}

# Execute a command with a timeout, capturing combined stdout+stderr.
# Usage: output=$(run_cmd "nix flake check" 300)
run_cmd() {
  local cmd="$1"
  local timeout="${2:-120}"
  local out
  out="$(timeout "$timeout" bash -c "$cmd" 2>&1)" || true
  echo "$out"
}

# Validate that the command has at least N positional args.
# Usage: require_args "$args" 1 "Usage: /cmd <arg>" || return
require_args() {
  local args="$1"
  local min="${2:-1}"
  local usage="${3:-Missing required argument}"

  local count=0
  if [[ -n "$args" ]]; then
    count=1
    local rest="${args}"
    while [[ "$rest" == *" "* ]]; do
      rest="${rest#* }"
      (( count++ ))
    done
  fi

  if (( count < min )); then
    return 1
  fi
  return 0
}

# Validate that GitLab token is configured. Sends error to chat if not.
# Usage: require_gitlab "$chat" || return
require_gitlab() {
  local chat="$1"
  if [[ -z "$GITLAB_TOKEN" ]]; then
    send_msg "$chat" "❌ GitLab token not configured."
    return 1
  fi
  return 0
}
