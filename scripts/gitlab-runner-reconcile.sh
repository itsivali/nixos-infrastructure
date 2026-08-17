#!/run/current-system/sw/bin/bash
# gitlab-runner-reconcile.sh — recover GitLab Runner service
#
# Triggered by gitlab-runner-health.service on failure.
# Attempts to restore the runner to a healthy state.
#
# NEVER modifies the Nix store or runs nixos-rebuild.
# All recovery is limited to service management and re-registration.

set -Eeuo pipefail

REPO_DIR="/home/ivali/nixos-infrastructure"
SCRIPTS_DIR="${REPO_DIR}/scripts"
NOTIFY="${SCRIPTS_DIR}/notify.sh"
CONFIG="/var/lib/gitlab-runner/.gitlab-runner/config.toml"
TOKEN_FILE="${TOKEN_FILE:-/run/secrets/gitlab-runner-token}"
SERVER="https://gitlab.com"

# GitLab API token for checking the private repository (path to the sops
# secret, so the value is never baked into the unit).
GITLAB_TOKEN="${GITLAB_TOKEN:-$(cat "${GITLAB_TOKEN_FILE:-/run/secrets/gitlab_token}" 2>/dev/null || true)}"

# The runner service runs with HOME=/var/lib/gitlab-runner, so register and
# verify must target that config explicitly instead of root's default $HOME.
export CONFIG_FILE="$CONFIG"

HOST="${HOST_NAME:-$(hostname)}"
LOCK_FILE="/run/gitlab-runner-reconcile.lock"

log() { echo "[$(date -Iseconds)] $*"; }

notify() {
  if [[ -x "$NOTIFY" ]]; then
    "$NOTIFY" "$1" || true
  fi
}

notify_failure() {
  notify "GitLab Runner reconciliation failed on ${HOST}: $1"
}

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "Another reconciliation already running — skipping."
  exit 0
fi

FAILURES=0

run_step() {
  local desc="$1"
  shift
  log "  → ${desc}..."
  if "$@"; then
    log "  ✓ ${desc}"
  else
    log "  ✗ ${desc} — failed"
    FAILURES=$((FAILURES + 1))
  fi
}

##############################################################################
# 1. Token availability
##############################################################################

log "[1/5] Token check"

if [[ -f "$TOKEN_FILE" ]]; then
  log "  ✓ Token file present at ${TOKEN_FILE}"
else
  log "  ⚠ Token file missing — sops may not have mounted it"
fi

##############################################################################
# 2. GitLab Runner service
##############################################################################

log "[2/5] Service recovery"

run_step "Enabling gitlab-runner" systemctl enable gitlab-runner.service
run_step "Restarting gitlab-runner" systemctl restart gitlab-runner.service

sleep 2

if systemctl is-active --quiet gitlab-runner.service; then
  log "  ✓ gitlab-runner active"
else
  log "  ✗ gitlab-runner still inactive — attempting re-registration"
  FAILURES=$((FAILURES + 1))

  if [[ -f "$TOKEN_FILE" ]]; then
    TOKEN="$(grep -oP '(?<=CI_SERVER_TOKEN=)\S+' "$TOKEN_FILE" || echo)"
    URL="$(grep -oP '(?<=CI_SERVER_URL=)\S+' "$TOKEN_FILE" || echo "$SERVER")"
    if [[ -n "$TOKEN" ]]; then
      run_step "Removing stale config" rm -f "$CONFIG"
      run_step "Re-registering runner" gitlab-runner register \
        --non-interactive \
        --url "$URL" \
        --registration-token "$TOKEN" \
        --executor "shell" \
        --tag-list "nixos,prague,self-hosted" \
        --run-untagged="true" \
        --locked="false"
      run_step "Restarting after registration" systemctl restart gitlab-runner.service
    else
      log "  ✗ Token file is empty — cannot register"
      FAILURES=$((FAILURES + 1))
    fi
  fi
fi

##############################################################################
# 3. Configuration integrity
##############################################################################

log "[3/5] Configuration check"

if [[ -f "$CONFIG" ]]; then
  log "  ✓ config.toml present"
else
  log "  ✗ config.toml missing — runner registration may have failed"
  FAILURES=$((FAILURES + 1))
fi

##############################################################################
# 4. GitLab reachable
##############################################################################

log "[4/5] Connectivity check"

if curl --silent --fail --connect-timeout 10 --max-time 15 "$SERVER" >/dev/null; then
  log "  ✓ GitLab reachable"
else
  log "  ✗ Cannot reach GitLab — network issue (not recovered)"
  FAILURES=$((FAILURES + 1))
fi

if [[ -n "${GITLAB_TOKEN:-}" ]]; then
  if curl --silent --fail --connect-timeout 10 --max-time 15 \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "https://gitlab.com/api/v4/projects/willisivali%2Fnixos-infrastructure/repository/branches/main" \
    >/dev/null 2>&1; then
    log "  ✓ Repository reachable (via API)"
  else
    log "  ✗ Cannot access repository"
    FAILURES=$((FAILURES + 1))
  fi
elif git ls-remote --heads "$SERVER/willisivali/nixos-infrastructure.git" main >/dev/null 2>&1; then
  log "  ✓ Repository reachable"
else
  log "  ✗ Cannot access repository"
  FAILURES=$((FAILURES + 1))
fi

##############################################################################
# 5. GitOps worktree
##############################################################################

log "[5/5] Worktree check"

WORKTREE="${GITOPS_WORKTREE:-/var/lib/gitops}"

if [[ -d "$WORKTREE" ]]; then
  log "  ✓ Worktree exists"
  if [[ ! -f "$WORKTREE/flake.nix" ]]; then
    log "  ⚠ Worktree has no flake.nix — may need initial clone"
  fi
else
  log "  ⚠ Worktree missing — creating"
  mkdir -p "$WORKTREE"
  CLONE_URL="$SERVER/willisivali/nixos-infrastructure.git"
  if [[ -n "${GITLAB_TOKEN:-}" ]]; then
    CLONE_URL="https://oauth2:${GITLAB_TOKEN}@gitlab.com/willisivali/nixos-infrastructure.git"
  fi
  run_step "Cloning repository" git clone \
    "$CLONE_URL" \
    "$WORKTREE"
fi

##############################################################################
# Summary
##############################################################################

log "=== Summary: ${FAILURES} failure(s)"

if (( FAILURES == 0 )); then
  log "GitLab Runner reconciliation succeeded"
  notify "GitLab Runner recovered on ${HOST}"
  exit 0
else
  log "GitLab Runner reconciliation incomplete"
  notify_failure "${FAILURES} issue(s) could not be recovered"
  exit 1
fi
