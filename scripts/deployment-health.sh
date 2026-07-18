#!/usr/bin/env bash
#
# ==============================================================================
# Fleet Deployment Health Check
# ==============================================================================
#
# Purpose:
#   Validates that this machine is safe to participate in GitOps operations.
#
# This includes:
#   - Network health
#   - DNS resolution
#   - GitLab availability
#   - GitOps repository reachability
#   - Local GitOps checkout validation
#   - Nix flake evaluation safety
#   - System health baseline
#
# This script NEVER modifies state.
#
# If it fails → gitops-reconciler.service is triggered by systemd.
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

# Bounds for network calls that have no built-in timeout (git, nix).
GIT_TIMEOUT="${GIT_TIMEOUT:-10}"
NIX_TIMEOUT="${NIX_TIMEOUT:-20}"

# STRICT_HEALTH=true  → connectivity/GitLab/bot-API failures FAIL the check.
#                       Used as the post-deploy gate by gitops-reconcile.sh, so a
#                       deploy that breaks networking is rolled back.
# STRICT_HEALTH=false → those same checks only WARN, while down critical services
#                       still FAIL. Used by the periodic observer via
#                       rollback-on-failure.service so a transient network blip does
#                       NOT trigger a (harmful, looping) rollback.
STRICT_HEALTH="${STRICT_HEALTH:-true}"
gate() {
  if [[ "$STRICT_HEALTH" == "true" ]]; then
    fail "$1"
  else
    warn "$1 (observer mode: not gating)"
  fi
}

# softfail: ALWAYS warn, never fail. For checks that are about EXTERNAL
# reachability (GitLab, the GitOps remote), not about this host's health. A
# flaky GitLab or a transient git fetch must NEVER roll the system back — a
# rollback cannot fix an upstream outage and would only churn generations.
softfail() {
  warn "$1 (external dependency — not gating)"
}

################################################################################
# Stats
################################################################################

TOTAL=0
PASS=0
WARN=0
FAIL=0
START_TIME=$SECONDS

################################################################################
# Logging
################################################################################

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ts() { date --iso-8601=seconds; }

log()  { echo "[$(ts)] $*"; }
ok()   { TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); log "  ✓ $1"; }
warn() { TOTAL=$((TOTAL+1)); WARN=$((WARN+1)); log "  ⚠ $1"; }
fail() { TOTAL=$((TOTAL+1)); FAIL=$((FAIL+1)); log "  ✗ $1"; }

section() {
  local icon="$1" title="$2"
  log ""
  log "$SEP"
  log "${icon}  ${title}"
  log "$SEP"
}

################################################################################
# 1. Basic system sanity
################################################################################

section "🖥️ " "System Health"

if systemctl is-system-running --quiet 2>/dev/null; then
  ok "systemd running normally"
else
  state="$(systemctl is-system-running 2>/dev/null || true)"
  warn "systemd reports degraded state (${state:-unknown})"
fi

if systemctl is-active --quiet network-online.target; then
  ok "network-online.target active"
else
  fail "network not fully online"
fi

################################################################################
# 2. DNS + Internet
################################################################################

section "🌐" "Network Connectivity"

if ping_out="$(ping -c 1 -W 2 1.1.1.1 2>&1)"; then
  rtt="$(sed -n 's/.*time=\([0-9.]*\).*/\1/p' <<< "$ping_out" | head -1)"
  ok "Internet reachable (1.1.1.1${rtt:+, ${rtt}ms})"
else
  gate "No internet connectivity"
fi

if command -v dig >/dev/null; then
  resolved="$(dig +time=2 +tries=1 gitlab.com +short 2>/dev/null | head -1)"
  if [[ -n "$resolved" ]]; then
    ok "DNS resolution working (gitlab.com → ${resolved})"
  else
    gate "DNS failure for gitlab.com"
  fi
else
  warn "dig not available"
fi

################################################################################
# 3. GitLab availability
################################################################################

section "🦊" "GitLab Health"

curl_out="$(curl -s --max-time 8 -o /dev/null -w '%{http_code}|%{time_total}' https://gitlab.com 2>/dev/null || true)"
http_code="${curl_out%%|*}"
resp_time="${curl_out##*|}"

if [[ "$http_code" =~ ^[23] ]]; then
  ok "GitLab reachable (HTTP ${http_code}, ${resp_time}s)"
else
  softfail "GitLab unreachable${http_code:+ (HTTP ${http_code})}"
fi

################################################################################
# 4. GitOps repository validation
################################################################################

section "📦" "GitOps Repository"

if [[ -z "$GITOPS_REPO" ]]; then
  softfail "GITOPS_REPO not set"
else
  log "  Repo    : $GITOPS_REPO"
  log "  Branch  : $GITOPS_BRANCH"

  remote_ref="$(timeout "$GIT_TIMEOUT" git ls-remote --heads "$GITOPS_REPO" "$GITOPS_BRANCH" 2>/dev/null || true)"
  if [[ -n "$remote_ref" ]]; then
    remote_hash="${remote_ref:0:7}"
    ok "Repository reachable + branch exists (HEAD ${remote_hash})"
  else
    softfail "Cannot reach GitOps repo or branch missing (${GIT_TIMEOUT}s timeout)"
  fi
fi

################################################################################
# 5. Local GitOps worktree validation
################################################################################

section "📁" "Local GitOps State"

if [[ -d "$GITOPS_WORKTREE" ]]; then

  ok "Worktree exists ($GITOPS_WORKTREE)"

  cd "$GITOPS_WORKTREE" || true

  if [[ -f flake.nix ]]; then
    ok "flake.nix present"
  else
    fail "flake.nix missing"
  fi

  if [[ -f flake.lock ]]; then
    lock_mtime="$(date -r flake.lock +%s 2>/dev/null || date +%s)"
    now_epoch="$(date +%s)"
    lock_age_days=$(( (now_epoch - lock_mtime) / 86400 ))
    ok "flake.lock present (${lock_age_days}d old)"
  else
    warn "flake.lock missing"
  fi

  if local_hash="$(git rev-parse --short HEAD 2>/dev/null)"; then
    dirty=""
    if [[ -n "$(git status --porcelain 2>/dev/null || true)" ]]; then
      dirty=" — uncommitted changes"
    fi
    ok "git repository valid (HEAD ${local_hash}${dirty})"
  else
    fail "git repository corrupted"
  fi

  if timeout "$NIX_TIMEOUT" nix flake metadata >/dev/null 2>&1; then
    ok "flake metadata evaluates"
  else
    fail "flake evaluation failed (or timed out after ${NIX_TIMEOUT}s)"
  fi

else
  warn "No local GitOps checkout found"
fi

################################################################################
# 6. System baseline checks
################################################################################

section "🧭" "System Baseline"

if systemctl is-active --quiet tailscaled 2>/dev/null; then
  ts_ip=""
  if command -v tailscale >/dev/null 2>&1; then
    ts_ip="$(tailscale ip -4 2>/dev/null | head -1 || true)"
  fi
  ok "Tailscale running${ts_ip:+ (${ts_ip})}"
else
  warn "Tailscale not active"
fi

if command -v timedatectl >/dev/null 2>&1; then
  if [[ "$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || true)" == "yes" ]]; then
    ok "Clock synchronized (NTP)"
  else
    warn "Clock not NTP-synchronized — may cause TLS/git auth failures"
  fi
else
  warn "timedatectl not available"
fi

################################################################################
# 7. Critical service units (always gates — a down unit is a real regression)
################################################################################

section "🔧" "Critical Services"

check_unit() {
  local unit="$1" label="$2"
  if ! systemctl list-unit-files "${unit}" >/dev/null 2>&1; then
    warn "not installed on this host: ${label}"
    return
  fi
  if systemctl is-active --quiet "${unit}"; then
    ok "${label} active"
  else
    fail "${label} is NOT running"
  fi
}

check_unit "ivali-bot-go.service" "Telegram bot (ivali-bot-go)"
check_unit "sshd.service" "SSH daemon (sshd)"
check_unit "NetworkManager.service" "NetworkManager"
check_unit "tailscaled.service" "Tailscale (tailscaled)"

# nginx only matters if it is actually installed on this host
if systemctl list-unit-files "nginx.service" >/dev/null 2>&1; then
  check_unit "nginx.service" "nginx"
fi

# Graphical session is relevant on a workstation host
if systemctl is-active --quiet graphical.target; then
  ok "graphical session active"
else
  warn "graphical session not active (headless or display down)"
fi

################################################################################
# 8. Bot reachability (Telegram API round-trip) — gated by STRICT_HEALTH
################################################################################

section "🤖" "Bot Reachability"

BOT_TOKEN_FILE="/run/secrets/telegram_bot_token"
if [[ -r "$BOT_TOKEN_FILE" ]]; then
  bt="$(tr -d '[:space:]' < "$BOT_TOKEN_FILE" 2>/dev/null || true)"
  if [[ -n "$bt" ]]; then
    resp="$(curl -s --max-time 8 "https://api.telegram.org/bot${bt}/getMe" 2>/dev/null || true)"
    if [[ "$resp" == *'"ok":true'* || "$resp" == *'"ok": true'* ]]; then
      ok "Bot token valid + can reach Telegram API"
    else
      gate "Bot cannot reach Telegram API (invalid token or network down)"
    fi
  else
    warn "Bot token file empty"
  fi
else
  warn "Bot token not available at ${BOT_TOKEN_FILE} — skipping bot ping"
fi

################################################################################
# Summary
################################################################################

DURATION=$((SECONDS - START_TIME))

section "📋" "Summary"

log "  Host     : $HOST_NAME"
log "  Repo     : ${GITOPS_REPO:-<unset>}"
log "  Branch   : $GITOPS_BRANCH"
log "  Duration : ${DURATION}s"
log ""
log "    ✓ Passed    : $PASS"
log "    ⚠ Warnings  : $WARN"
log "    ✗ Failed    : $FAIL"
log "    ──────────────────"
log "    Σ Total     : $TOTAL"
log ""
log "$SEP"

if [[ "$FAIL" -gt 0 ]]; then
  log "❌  DEPLOYMENT HEALTH: FAILED"
  log "$SEP"
  exit 1
fi

log "✅  DEPLOYMENT HEALTH: PASSED"
log "$SEP"
exit 0
