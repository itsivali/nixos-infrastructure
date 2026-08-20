#!/usr/bin/env bash
#
# ==============================================================================
# Fleet Deployment Health Check
# ==============================================================================
#
# Purpose:
#   Validates that this machine is healthy for GitOps operations.
#
# Checks:
#   1. System Health (systemd, network-online)
#   2. Network Connectivity (ping, DNS)
#   3. GitLab Availability
#   4. GitOps Repository
#   5. Local GitOps State (flake, git, generations)
#   6. System Baseline (Tailscale, NTP)
#   7. Critical Services (sshd, NetworkManager, tailscaled, bot)
#   8. Disk Usage
#   9. Bot Reachability (Telegram API)
#
# Usage:
#   deployment-health.sh           # Human-readable output
#   deployment-health.sh --json    # JSON output for programmatic consumers
#
# This script NEVER modifies state.
#
# ==============================================================================

set -Eeuo pipefail

################################################################################
# Environment (injected by Nix)
################################################################################

HOST_NAME="${HOST_NAME:-unknown}"
GITOPS_REPO="${GITOPS_REPO:-}"
GITOPS_BRANCH="${GITOPS_BRANCH:-main}"
GITOPS_WORKTREE="${GITOPS_WORKTREE:-/var/lib/gitops}"

# Bounds for network calls
GIT_TIMEOUT="${GIT_TIMEOUT:-10}"
NIX_TIMEOUT="${NIX_TIMEOUT:-20}"

# STRICT_HEALTH=true  → connectivity failures FAIL the check
# STRICT_HEALTH=false → connectivity failures only WARN
STRICT_HEALTH="${STRICT_HEALTH:-true}"

# JSON_OUTPUT=true → emit JSON and exit
JSON_OUTPUT="${JSON_OUTPUT:-false}"

################################################################################
# Output mode
################################################################################

if [[ "${1:-}" == "--json" ]]; then
  JSON_OUTPUT=true
fi

################################################################################
# Helpers
################################################################################

ts() { date --iso-8601=seconds; }
log()  { echo "[$(ts)] $*"; }

# Check results accumulator
CHECK_RESULTS=()
TOTAL=0
PASS=0
WARN=0
FAIL=0
START_TIME=$SECONDS

record_check() {
  local name="$1" status="$2" message="$3"
  TOTAL=$((TOTAL+1))
  case "$status" in
    pass) PASS=$((PASS+1)) ;;
    warn) WARN=$((WARN+1)) ;;
    fail) FAIL=$((FAIL+1)) ;;
  esac
  CHECK_RESULTS+=("{\"name\":\"${name}\",\"status\":\"${status}\",\"message\":\"$(echo "$message" | sed 's/"/\\"/g')\"}")
}

gate() {
  if [[ "$STRICT_HEALTH" == "true" ]]; then
    record_check "$1" "fail" "$2"
  else
    record_check "$1" "warn" "$2 (observer: not gating)"
  fi
}

softfail() {
  record_check "$1" "warn" "$2 (external: not gating)"
}

################################################################################
# Adaptive Grace Period — wait for critical services
################################################################################

wait_for_services() {
  local max_wait="${1:-60}"
  local interval=2
  local elapsed=0
  while (( elapsed < max_wait )); do
    local all_ok=true
    for unit in sshd.service NetworkManager.service; do
      if systemctl is-active --quiet "$unit" 2>/dev/null; then
        continue
      fi
      all_ok=false
      break
    done
    if $all_ok; then return 0; fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  return 1
}

################################################################################
# 1. Basic system sanity
################################################################################

check_system() {
  if systemctl is-system-running --quiet 2>/dev/null; then
    record_check "systemd" "pass" "running normally"
  else
    local state
    state="$(systemctl is-system-running 2>/dev/null || true)"
    record_check "systemd" "warn" "degraded state (${state:-unknown})"
  fi

  if systemctl is-active --quiet network-online.target; then
    record_check "network-online" "pass" "active"
  else
    record_check "network-online" "warn" "not active (transient)"
  fi
}

################################################################################
# 2. DNS + Internet
################################################################################

check_network() {
  local ping_out
  if ping_out="$(ping -c 1 -W 2 1.1.1.1 2>/dev/null)"; then
    local rtt
    rtt="$(sed -n 's/.*time=\([0-9.]*\).*/\1/p' <<< "$ping_out" | head -1)"
    record_check "ping" "pass" "1.1.1.1 reachable${rtt:+, ${rtt}ms}"
  else
    gate "ping" "no internet connectivity"
  fi

  if command -v dig >/dev/null; then
    local resolved
    resolved="$(dig +time=2 +tries=1 gitlab.com +short 2>/dev/null | head -1)"
    if [[ -n "$resolved" ]]; then
      record_check "dns" "pass" "gitlab.com -> ${resolved}"
    else
      gate "dns" "DNS failure for gitlab.com"
    fi
  else
    record_check "dns" "warn" "dig not available"
  fi
}

################################################################################
# 3. GitLab availability
################################################################################

check_gitlab() {
  local curl_out http_code resp_time
  curl_out="$(curl -s --max-time 8 -o /dev/null -w '%{http_code}|%{time_total}' https://gitlab.com 2>/dev/null || true)"
  http_code="${curl_out%%|*}"
  resp_time="${curl_out##*|}"

  if [[ "$http_code" =~ ^[23] ]]; then
    record_check "gitlab" "pass" "HTTP ${http_code} (${resp_time}s)"
  else
    softfail "gitlab" "GitLab unreachable${http_code:+ (HTTP ${http_code})}"
  fi
}

################################################################################
# 4. GitOps repository validation
################################################################################

check_gitops_repo() {
  if [[ -z "$GITOPS_REPO" ]]; then
    softfail "gitops-repo" "GITOPS_REPO not set"
    return
  fi

  local remote_ref
  remote_ref="$(timeout "$GIT_TIMEOUT" git ls-remote --heads "$GITOPS_REPO" "$GITOPS_BRANCH" 2>/dev/null || true)"
  if [[ -n "$remote_ref" ]]; then
    local remote_hash="${remote_ref:0:7}"
    record_check "gitops-repo" "pass" "reachable, HEAD ${remote_hash}"
  else
    softfail "gitops-repo" "cannot reach repo or branch missing (${GIT_TIMEOUT}s timeout)"
  fi
}

################################################################################
# 5. Local GitOps worktree validation
################################################################################

check_worktree() {
  if [[ ! -d "$GITOPS_WORKTREE" ]]; then
    record_check "worktree" "warn" "no local checkout at ${GITOPS_WORKTREE}"
    return
  fi

  record_check "worktree" "pass" "${GITOPS_WORKTREE} exists"

  local flake_nix="$GITOPS_WORKTREE/flake.nix"
  if [[ -f "$flake_nix" ]]; then
    record_check "flake-nix" "pass" "present"
  else
    record_check "flake-nix" "fail" "missing"
  fi

  local flake_lock="$GITOPS_WORKTREE/flake.lock"
  if [[ -f "$flake_lock" ]]; then
    local lock_mtime now_epoch lock_age_days
    lock_mtime="$(date -r "$flake_lock" +%s 2>/dev/null || date +%s)"
    now_epoch="$(date +%s)"
    lock_age_days=$(( (now_epoch - lock_mtime) / 86400 ))
    record_check "flake-lock" "pass" "${lock_age_days}d old"
  else
    record_check "flake-lock" "warn" "missing"
  fi

  local git_dir="$GITOPS_WORKTREE"
  if local_hash="$(git -C "$git_dir" rev-parse --short HEAD 2>/dev/null)"; then
    local dirty=""
    if [[ -n "$(git -C "$git_dir" status --porcelain 2>/dev/null || true)" ]]; then
      dirty=" — uncommitted changes"
    fi
    record_check "git-status" "pass" "HEAD ${local_hash}${dirty}"
  else
    record_check "git-status" "fail" "git repository corrupted"
  fi

  if timeout "$NIX_TIMEOUT" nix flake metadata "$git_dir" >/dev/null 2>&1; then
    record_check "flake-eval" "pass" "metadata evaluates"
  else
    record_check "flake-eval" "warn" "evaluation failed or timed out (${NIX_TIMEOUT}s)"
  fi
}

################################################################################
# 6. System baseline checks
################################################################################

check_baseline() {
  if systemctl is-active --quiet tailscaled 2>/dev/null; then
    local ts_ip=""
    if command -v tailscale >/dev/null 2>&1; then
      ts_ip="$(tailscale ip -4 2>/dev/null | head -1 || true)"
    fi
    record_check "tailscale" "pass" "running${ts_ip:+ (${ts_ip})}"
  else
    record_check "tailscale" "warn" "not active"
  fi

  if command -v timedatectl >/dev/null 2>&1; then
    if [[ "$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || true)" == "yes" ]]; then
      record_check "ntp" "pass" "synchronized"
    else
      record_check "ntp" "warn" "not NTP-synchronized"
    fi
  else
    record_check "ntp" "warn" "timedatectl not available"
  fi
}

################################################################################
# 7. Critical service units
################################################################################

check_services() {
  local services=("sshd.service" "NetworkManager.service" "tailscaled.service")

  # Add nginx only if installed
  if systemctl list-unit-files "nginx.service" >/dev/null 2>&1; then
    services+=("nginx.service")
  fi

  for unit in "${services[@]}"; do
    local label="${unit%.service}"
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
      record_check "$label" "pass" "active"
    else
      local detail
      detail="$(systemctl status "$unit" --no-pager -l 2>&1 | head -3 || true)"
      gate "$label" "NOT running — ${detail}"
    fi
  done

  # Bot with retry (always restarts during deploy)
  local bot_ok=false
  for ((i = 1; i <= 12; i++)); do
    if systemctl list-unit-files "ivali-bot-go.service" >/dev/null 2>&1 && \
       systemctl is-active --quiet "ivali-bot-go.service"; then
      bot_ok=true
      break
    fi
    if (( i < 12 )); then
      sleep 5
    fi
  done

  if $bot_ok; then
    record_check "ivali-bot" "pass" "active"
  else
    gate "ivali-bot" "NOT running after 60s retry"
  fi

  # Graphical session
  if systemctl is-active --quiet graphical.target; then
    record_check "graphical" "pass" "active"
  else
    record_check "graphical" "warn" "not active (headless or display down)"
  fi
}

################################################################################
# 8. Disk usage
################################################################################

check_disk() {
  local disk_pct
  disk_pct="$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')"
  if [[ "$disk_pct" =~ ^[0-9]+$ ]]; then
    if (( disk_pct >= 90 )); then
      record_check "disk" "fail" "${disk_pct}% used (/)"
    elif (( disk_pct >= 80 )); then
      record_check "disk" "warn" "${disk_pct}% used (/)"
    else
      record_check "disk" "pass" "${disk_pct}% used (/)"
    fi
  else
    record_check "disk" "warn" "could not determine usage"
  fi

  # Nix store
  local nix_pct
  nix_pct="$(df -h /nix/store 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')"
  if [[ "$nix_pct" =~ ^[0-9]+$ ]]; then
    if (( nix_pct >= 90 )); then
      record_check "nix-store" "fail" "${nix_pct}% used (/nix/store)"
    elif (( nix_pct >= 80 )); then
      record_check "nix-store" "warn" "${nix_pct}% used (/nix/store)"
    else
      record_check "nix-store" "pass" "${nix_pct}% used (/nix/store)"
    fi
  fi
}

################################################################################
# 9. NixOS generations
################################################################################

check_generations() {
  local gen_count
  gen_count="$(nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | wc -l)"
  gen_count="$(echo "$gen_count" | tr -d '[:space:]')"
  if [[ "$gen_count" =~ ^[0-9]+$ ]]; then
    if (( gen_count >= 2 )); then
      record_check "generations" "pass" "${gen_count} generations (rollback available)"
    elif (( gen_count == 1 )); then
      record_check "generations" "warn" "only 1 generation (no rollback possible)"
    else
      record_check "generations" "warn" "could not determine generation count"
    fi
  else
    record_check "generations" "warn" "could not determine generation count"
  fi
}

################################################################################
# 10. Bot reachability (Telegram API)
################################################################################

check_bot() {
  local bot_token_file="/run/secrets/telegram_bot_token"
  if [[ -r "$bot_token_file" ]]; then
    local bt
    bt="$(tr -d '[:space:]' < "$bot_token_file" 2>/dev/null || true)"
    if [[ -n "$bt" ]]; then
      local resp
      resp="$(curl -s --max-time 8 "https://api.telegram.org/bot${bt}/getMe" 2>/dev/null || true)"
      if [[ "$resp" == *'"ok":true'* || "$resp" == *'"ok": true'* ]]; then
        record_check "bot-reachability" "pass" "token valid, API reachable"
      else
        record_check "bot-reachability" "warn" "API error (transient)"
      fi
    else
      record_check "bot-reachability" "warn" "token file empty"
    fi
  else
    record_check "bot-reachability" "warn" "token not available at ${bot_token_file}"
  fi
}

################################################################################
# Emit JSON results
################################################################################

emit_json() {
  local checks_json
  checks_json=$(printf '%s,' "${CHECK_RESULTS[@]}")
  checks_json="[${checks_json%,}]"

  cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "host": "${HOST_NAME}",
  "strict_health": ${STRICT_HEALTH},
  "passed": ${PASS},
  "warned": ${WARN},
  "failed": ${FAIL},
  "total": ${TOTAL},
  "duration_seconds": $((SECONDS - START_TIME)),
  "checks": ${checks_json}
}
EOF
}

################################################################################
# Emit human-readable results
################################################################################

emit_human() {
  local SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  echo ""
  echo "${SEP}"
  echo "💓  Deployment Health — ${HOST_NAME}"
  echo "${SEP}"
  echo ""

  for result in "${CHECK_RESULTS[@]}"; do
    local name status message
    name="$(echo "$result" | sed 's/.*"name":"\([^"]*\)".*/\1/')"
    status="$(echo "$result" | sed 's/.*"status":"\([^"]*\)".*/\1/')"
    message="$(echo "$result" | sed 's/.*"message":"\([^"]*\)".*/\1/')"

    local icon="✅"
    case "$status" in
      warn) icon="⚠️" ;;
      fail) icon="❌" ;;
    esac

    printf "  %s %-20s %s\n" "$icon" "$name" "$message"
  done

  echo ""
  echo "${SEP}"
  echo "  ✓ Passed    : ${PASS}"
  echo "  ⚠ Warnings  : ${WARN}"
  echo "  ✗ Failed    : ${FAIL}"
  echo "  ──────────────────"
  echo "  Σ Total     : ${TOTAL}"
  echo "  ⏱ Duration  : $((SECONDS - START_TIME))s"
  echo "${SEP}"
  echo ""

  if [[ "$FAIL" -gt 0 ]]; then
    echo "❌  DEPLOYMENT HEALTH: FAILED"
  else
    echo "✅  DEPLOYMENT HEALTH: PASSED"
  fi
  echo "${SEP}"
}

################################################################################
# Write results files
################################################################################

write_results() {
  local results_dir="/var/lib/deployment-health"

  # Try to create directory (may fail if not running as root)
  if ! mkdir -p "$results_dir" 2>/dev/null; then
    # Can't write results — skip silently
    return 0
  fi

  mkdir -p "$results_dir/history" 2>/dev/null || true

  # Write current results
  emit_json > "$results_dir/last-results.json" 2>/dev/null || true

  # Write last-ok marker for Prometheus
  if [[ "$FAIL" -gt 0 ]]; then
    # Collect failed checks for alert
    local failed_checks=""
    for result in "${CHECK_RESULTS[@]}"; do
      local status
      status="$(echo "$result" | sed 's/.*"status":"\([^"]*\)".*/\1/')"
      if [[ "$status" == "fail" ]]; then
        local name message
        name="$(echo "$result" | sed 's/.*"name":"\([^"]*\)".*/\1/')"
        message="$(echo "$result" | sed 's/.*"message":"\([^"]*\)".*/\1/')"
        failed_checks="${failed_checks}  ✗ ${name}: ${message}\n"
      fi
    done

    # Send proactive alert via notify.sh
    if [[ -x "/etc/profiles/per-user/root/bin/notify" ]]; then
      /etc/profiles/per-user/root/bin/notify "🚨 Health check failed on ${HOST_NAME}

Failed: ${FAIL} checks
$(echo -e "$failed_checks")
Time: $(date -Iseconds)" 2>/dev/null || true
    fi
  else
    touch /tmp/deployment-health-last-ok 2>/dev/null || true
  fi

  # History: keep last 10
  local ts
  ts="$(date +%s)"
  cp "$results_dir/last-results.json" "$results_dir/history/result-${ts}.json" 2>/dev/null || true
  ls -t "$results_dir"/history/result-*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
}

################################################################################
# Rebuild-in-progress detection
################################################################################

# During a NixOS rebuild (nixos-rebuild switch), services are being
# started/stopped transiently. Running health checks at that point produces
# false failures that trigger unnecessary rollbacks.
#
# Exit 0 (healthy) when either:
#   1. nixos-rebuild is actively running, OR
#   2. systemd is in an activation/deactivation phase.

skip_if_rebuilding() {
  # Fast path: check for a running nixos-rebuild process
  if pgrep -x nixos-rebuild >/dev/null 2>&1; then
    log "nixos-rebuild is running — skipping health check"
    exit 0
  fi

  # Slow path: check systemd manager state for activation phases
  local mgr_state
  mgr_state="$(systemctl is-system-running 2>/dev/null || true)"
  case "$mgr_state" in
    activating|deactivating|maintenance)
      log "systemd is ${mgr_state} — skipping health check"
      exit 0
      ;;
  esac
}

skip_if_rebuilding

################################################################################
# Main
################################################################################

check_system
check_network
check_gitlab
check_gitops_repo
check_worktree
check_baseline
check_services
check_disk
check_generations
check_bot

write_results

if [[ "$JSON_OUTPUT" == "true" ]]; then
  emit_json
else
  emit_human
fi

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
