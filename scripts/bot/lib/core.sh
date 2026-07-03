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

# Execute a command with timeout and send output to chat.
# Usage: run_cmd_chat "$chat" "nix flake check" 300
run_cmd_chat() {
  local chat="$1"
  local cmd="$2"
  local timeout="${3:-120}"
  
  send_typing "$chat"
  
  local out
  out=$(run_cmd "$cmd" "$timeout")
  
  if [[ -z "$out" ]]; then
    send_msg "$chat" "✅ Command completed successfully (no output)"
  else
    send_long "$chat" "\`\`\`
${out}
\`\`\`"
  fi
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

# Send error message with helpful context.
# Usage: send_error "$chat" "Error message" "suggestion"
send_error() {
  local chat="$1"
  local error="$2"
  local suggestion="${3:-}"
  
  local msg="❌ *Error*
${error}"
  
  if [[ -n "$suggestion" ]]; then
    msg+="
💡 *Suggestion:* ${suggestion}"
  fi
  
  send_msg "$chat" "$msg"
}

# Send success message.
# Usage: send_success "$chat" "Operation completed"
send_success() {
  local chat="$1"
  local message="$2"
  send_msg "$chat" "✅ ${message}"
}

# Send warning message.
# Usage: send_warning "$chat" "Warning message"
send_warning() {
  local chat="$1"
  local message="$2"
  send_msg "$chat" "⚠️ ${message}"
}

# Send info message.
# Usage: send_info "$chat" "Info message"
send_info() {
  local chat="$1"
  local message="$2"
  send_msg "$chat" "ℹ️ ${message}"
}

# Validate that GitLab token is configured. Sends error to chat if not.
# Usage: require_gitlab "$chat" || return
require_gitlab() {
  local chat="$1"
  if [[ -z "$GITLAB_TOKEN" ]]; then
    send_error "$chat" "GitLab token not configured" "Set up SOPS secrets with telegram.yaml"
    return 1
  fi
  return 0
}

# Validate that a command exists.
# Usage: require_command "tailscale" "$chat" || return
require_command() {
  local cmd="$1"
  local chat="${2:-}"
  
  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [[ -n "$chat" ]]; then
      send_error "$chat" "Command not found: ${cmd}" "Install ${cmd} package"
    fi
    return 1
  fi
  return 0
}

# Validate that a file exists.
# Usage: require_file "/path/to/file" "$chat" || return
require_file() {
  local file="$1"
  local chat="${2:-}"
  
  if [[ ! -f "$file" ]]; then
    if [[ -n "$chat" ]]; then
      send_error "$chat" "File not found: ${file}" "Check file path"
    fi
    return 1
  fi
  return 0
}

# Validate that a directory exists.
# Usage: require_directory "/path/to/dir" "$chat" || return
require_directory() {
  local dir="$1"
  local chat="${2:-}"
  
  if [[ ! -d "$dir" ]]; then
    if [[ -n "$chat" ]]; then
      send_error "$chat" "Directory not found: ${dir}" "Check directory path"
    fi
    return 1
  fi
  return 0
}

# Validate that we're in the correct directory.
# Usage: require_repo "$chat" || return
require_repo() {
  local chat="$1"
  
  if [[ ! -f "${REPO_DIR}/flake.nix" ]]; then
    send_error "$chat" "Not in NixOS repository" "Check REPO_DIR configuration"
    return 1
  fi
  return 0
}

# Validate that SOPS is available.
# Usage: require_sops "$chat" || return
require_sops() {
  local chat="$1"
  
  if ! command -v sops >/dev/null 2>&1; then
    send_error "$chat" "SOPS not found" "Install sops package"
    return 1
  fi
  return 0
}

# Validate that we have network connectivity.
# Usage: require_network "$chat" || return
require_network() {
  local chat="$1"
  
  if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    send_error "$chat" "No network connectivity" "Check network connection"
    return 1
  fi
  return 0
}

# Validate that we're running as root.
# Usage: require_root "$chat" || return
require_root() {
  local chat="$1"
  
  if [[ $EUID -ne 0 ]]; then
    send_error "$chat" "This command requires root privileges" "Run with sudo"
    return 1
  fi
  return 0
}

# Validate that we have enough disk space.
# Usage: require_disk_space 1024 "$chat" || return
require_disk_space() {
  local required_mb="$1"
  local chat="${2:-}"
  
  local available_mb=$(df -m / 2>/dev/null | awk 'NR==2{print $4}')
  
  if [[ "$available_mb" -lt "$required_mb" ]]; then
    if [[ -n "$chat" ]]; then
      send_error "$chat" "Insufficient disk space" "Need ${required_mb}MB, have ${available_mb}MB available"
    fi
    return 1
  fi
  return 0
}

# Validate that we have enough memory.
# Usage: require_memory 512 "$chat" || return
require_memory() {
  local required_mb="$1"
  local chat="${2:-}"
  
  local available_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $7}')
  
  if [[ "$available_mb" -lt "$required_mb" ]]; then
    if [[ -n "$chat" ]]; then
      send_error "$chat" "Insufficient memory" "Need ${required_mb}MB, have ${available_mb}MB available"
    fi
    return 1
  fi
  return 0
}

# Validate that a service is running.
# Usage: require_service "nginx" "$chat" || return
require_service() {
  local service="$1"
  local chat="${2:-}"
  
  if ! systemctl is-active --quiet "$service" 2>/dev/null; then
    if [[ -n "$chat" ]]; then
      send_error "$chat" "Service ${service} is not running" "Start with: systemctl start ${service}"
    fi
    return 1
  fi
  return 0
}

# Validate that a service is enabled.
# Usage: require_service_enabled "nginx" "$chat" || return
require_service_enabled() {
  local service="$1"
  local chat="${2:-}"
  
  if ! systemctl is-enabled --quiet "$service" 2>/dev/null; then
    if [[ -n "$chat" ]]; then
      send_error "$chat" "Service ${service} is not enabled" "Enable with: systemctl enable ${service}"
    fi
    return 1
  fi
  return 0
}

# Validate that we have internet access.
# Usage: require_internet "$chat" || return
require_internet() {
  local chat="$1"
  
  if ! curl -s --max-time 5 https://google.com >/dev/null 2>&1; then
    send_error "$chat" "No internet access" "Check network connection"
    return 1
  fi
  return 0
}

# Validate that we have GitHub access.
# Usage: require_github "$chat" || return
require_github() {
  local chat="$1"
  
  if ! curl -s --max-time 5 https://github.com >/dev/null 2>&1; then
    send_error "$chat" "Cannot access GitHub" "Check network connection or GitHub status"
    return 1
  fi
  return 0
}

# Validate that we have GitLab access.
# Usage: require_gitlab_access "$chat" || return
require_gitlab_access() {
  local chat="$1"
  
  if ! curl -s --max-time 5 "${GITLAB_URL}" >/dev/null 2>&1; then
    send_error "$chat" "Cannot access GitLab" "Check network connection or GitLab status"
    return 1
  fi
  return 0
}
