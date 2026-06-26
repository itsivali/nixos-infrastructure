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

################################################################################
# Stats
################################################################################

TOTAL=0
PASS=0
WARN=0
FAIL=0

################################################################################
# Logging
################################################################################

ts() { date --iso-8601=seconds; }

log()  { echo "[$(ts)] $*"; }
ok()   { TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); log "✓ $1"; }
warn() { TOTAL=$((TOTAL+1)); WARN=$((WARN+1)); log "⚠ $1"; }
fail() { TOTAL=$((TOTAL+1)); FAIL=$((FAIL+1)); log "✗ $1"; }

section() {
  log ""
  log "============================================================"
  log "$1"
  log "============================================================"
}

################################################################################
# 1. Basic system sanity
################################################################################

section "System Health"

if systemctl is-system-running --quiet 2>/dev/null; then
  ok "systemd running normally"
else
  warn "systemd reports degraded state"
fi

if systemctl is-active --quiet network-online.target; then
  ok "network-online.target active"
else
  fail "network not fully online"
fi

################################################################################
# 2. DNS + Internet
################################################################################

section "Network Connectivity"

if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
  ok "Internet reachable (1.1.1.1)"
else
  fail "No internet connectivity"
fi

if command -v dig >/dev/null; then
  if dig gitlab.com +short >/dev/null 2>&1; then
    ok "DNS resolution working"
  else
    fail "DNS failure for gitlab.com"
  fi
else
  warn "dig not available"
fi

################################################################################
# 3. GitLab availability
################################################################################

section "GitLab Health"

if curl -fsS --max-time 8 https://gitlab.com >/dev/null; then
  ok "GitLab reachable"
else
  fail "GitLab unreachable"
fi

################################################################################
# 4. GitOps repository validation
################################################################################

section "GitOps Repository"

if [[ -z "$GITOPS_REPO" ]]; then
  fail "GITOPS_REPO not set"
else
  log "Repo    : $GITOPS_REPO"
  log "Branch  : $GITOPS_BRANCH"

  if git ls-remote --heads "$GITOPS_REPO" "$GITOPS_BRANCH" >/dev/null 2>&1; then
    ok "Repository reachable + branch exists"
  else
    fail "Cannot reach GitOps repo or branch missing"
  fi
fi

################################################################################
# 5. Local GitOps worktree validation
################################################################################

section "Local GitOps State"

if [[ -d "$GITOPS_WORKTREE" ]]; then

  ok "Worktree exists"

  cd "$GITOPS_WORKTREE" || true

  if [[ -f flake.nix ]]; then
    ok "flake.nix present"
  else
    fail "flake.nix missing"
  fi

  if [[ -f flake.lock ]]; then
    ok "flake.lock present"
  else
    warn "flake.lock missing"
  fi

  if git rev-parse HEAD >/dev/null 2>&1; then
    ok "git repository valid"
  else
    fail "git repository corrupted"
  fi

  if nix flake metadata >/dev/null 2>&1; then
    ok "flake metadata evaluates"
  else
    fail "flake evaluation failed"
  fi

else
  warn "No local GitOps checkout found"
fi

################################################################################
# 6. System baseline checks
################################################################################

section "System Baseline"

if systemctl is-active --quiet tailscaled 2>/dev/null; then
  ok "Tailscale running"
else
  warn "Tailscale not active"
fi

################################################################################
# Summary
################################################################################

section "Summary"

log "Host     : $HOST_NAME"
log "Repo     : $GITOPS_REPO"
log "Branch   : $GITOPS_BRANCH"
log ""
log "Total    : $TOTAL"
log "Passed   : $PASS"
log "Warnings : $WARN"
log "Failed   : $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  log ""
  log "❌ Deployment health FAILED"
  exit 1
fi

log ""
log "✅ Deployment health PASSED"
exit 0
