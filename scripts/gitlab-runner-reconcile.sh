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

GITLAB_TOKEN="${GITLAB_TOKEN:-$(cat "${GITLAB_TOKEN_FILE:-/run/secrets/gitlab_token}" 2>/dev/null || true)}"

export CONFIG_FILE="$CONFIG"

HOST="${HOST_NAME:-$(hostname)}"
LOCK_FILE="/run/gitlab-runner-reconcile.lock"
TRIGGER="${TRIGGER:-timer}"
STATE_FILE="/var/lib/gitlab-runner/reconcile-state.json"

# Capture full output for structured report
OUTPUT=""
REPORT=""
FAILURES=0
STEPS=()

log() { echo "[$(date -Iseconds)] $*"; }

append_report() {
  REPORT+="$1"$'\n'
}

run_step() {
  local name="$1"
  shift
  log "  → ${name}..."
  local step_output
  if step_output="$("$@" 2>&1)"; then
    log "  ✓ ${name}"
    STEPS+=("{\"name\":\"${name}\",\"status\":\"ok\"}")
    append_report "  ✅ ${name}"
  else
    log "  ✗ ${name} — failed"
    FAILURES=$((FAILURES + 1))
    STEPS+=("{\"name\":\"${name}\",\"status\":\"fail\",\"error\":\"$(echo "$step_output" | head -1 | sed 's/"/\\"/g')\"}")
    append_report "  ❌ ${name}: $(echo "$step_output" | head -1)"
  fi
}

notify() {
  if [[ -x "$NOTIFY" ]]; then
    "$NOTIFY" "$1" || true
  fi
}

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "Another reconciliation already running — skipping."
  exit 0
fi

##############################################################################
# 1. Token availability
##############################################################################

log "[1/5] Token check"
TOKEN_STATUS="missing"

if [[ -f "$TOKEN_FILE" ]]; then
  log "  ✓ Token file present at ${TOKEN_FILE}"
  TOKEN_STATUS="present"
  append_report "  ✅ Token: present"
else
  log "  ⚠ Token file missing — sops may not have mounted it"
  append_report "  ⚠️ Token: missing"
fi

##############################################################################
# 2. GitLab Runner service
##############################################################################

log "[2/5] Service recovery"

SERVICE_RESTARTED=false

if systemctl is-active --quiet gitlab-runner.service; then
  log "  ✓ gitlab-runner already active"
  STEPS+=("{\"name\":\"service-check\",\"status\":\"ok\"}")
  append_report "  ✅ Service: already running"
else
  run_step "Enable gitlab-runner" systemctl enable gitlab-runner.service
  run_step "Restart gitlab-runner" systemctl restart gitlab-runner.service
  SERVICE_RESTARTED=true
  sleep 2

  if systemctl is-active --quiet gitlab-runner.service; then
    append_report "  ✅ Service: restarted (was inactive)"
  else
    append_report "  ❌ Service: still inactive after restart"
    # Try re-registration
    if [[ -f "$TOKEN_FILE" ]]; then
      TOKEN="$(grep -oP '(?<=CI_SERVER_TOKEN=)\S+' "$TOKEN_FILE" || echo)"
      URL="$(grep -oP '(?<=CI_SERVER_URL=)\S+' "$TOKEN_FILE" || echo "$SERVER")"
      if [[ -n "$TOKEN" ]]; then
        run_step "Remove stale config" rm -f "$CONFIG"
        run_step "Re-register runner" gitlab-runner register \
          --non-interactive \
          --url "$URL" \
          --registration-token "$TOKEN" \
          --executor "shell" \
          --tag-list "nixos,${HOST},self-hosted" \
          --run-untagged="true" \
          --locked="false"
        run_step "Restart after registration" systemctl restart gitlab-runner.service
      else
        log "  ✗ Token file is empty — cannot register"
        FAILURES=$((FAILURES + 1))
      fi
    fi
  fi
fi

##############################################################################
# 3. Configuration integrity
##############################################################################

log "[3/5] Configuration check"

if [[ -f "$CONFIG" ]]; then
  log "  ✓ config.toml present"
  append_report "  ✅ Config: present"
else
  log "  ✗ config.toml missing — runner registration may have failed"
  FAILURES=$((FAILURES + 1))
  append_report "  ❌ Config: missing"
fi

##############################################################################
# 4. GitLab reachable
##############################################################################

log "[4/5] Connectivity check"

if curl --silent --fail --connect-timeout 10 --max-time 15 "$SERVER" >/dev/null; then
  log "  ✓ GitLab reachable"
  append_report "  ✅ GitLab: reachable"
else
  log "  ✗ Cannot reach GitLab — network issue (not recovered)"
  FAILURES=$((FAILURES + 1))
  append_report "  ❌ GitLab: unreachable"
fi

if [[ -n "${GITLAB_TOKEN:-}" ]]; then
  if curl --silent --fail --connect-timeout 10 --max-time 15 \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "https://gitlab.com/api/v4/projects/willisivali%2Fnixos-infrastructure/repository/branches/main" \
    >/dev/null 2>&1; then
    log "  ✓ Repository reachable (via API)"
    append_report "  ✅ Repo: reachable (API)"
  else
    log "  ✗ Cannot access repository"
    FAILURES=$((FAILURES + 1))
    append_report "  ❌ Repo: inaccessible"
  fi
elif git ls-remote --heads "$SERVER/willisivali/nixos-infrastructure.git" main >/dev/null 2>&1; then
  log "  ✓ Repository reachable"
  append_report "  ✅ Repo: reachable"
else
  log "  ✗ Cannot access repository"
  FAILURES=$((FAILURES + 1))
  append_report "  ❌ Repo: inaccessible"
fi

##############################################################################
# 5. GitOps worktree
##############################################################################

log "[5/5] Worktree check"

WORKTREE="${GITOPS_WORKTREE:-/var/lib/gitops}"

if [[ -d "$WORKTREE" ]]; then
  log "  ✓ Worktree exists"
  append_report "  ✅ Worktree: ok"
  if [[ ! -f "$WORKTREE/flake.nix" ]]; then
    log "  ⚠ Worktree has no flake.nix — may need initial clone"
    append_report "  ⚠️ Worktree: missing flake.nix"
  fi
else
  log "  ⚠ Worktree missing — creating"
  mkdir -p "$WORKTREE"
  CLONE_URL="$SERVER/willisivali/nixos-infrastructure.git"
  if [[ -n "${GITLAB_TOKEN:-}" ]]; then
    CLONE_URL="https://oauth2:${GITLAB_TOKEN}@gitlab.com/willisivali/nixos-infrastructure.git"
  fi
  run_step "Clone repository" git clone "$CLONE_URL" "$WORKTREE"
fi

##############################################################################
# Summary + JSON state
##############################################################################

DURATION=$((SECONDS))
RESULT="success"
if (( FAILURES > 0 )); then
  RESULT="failure"
fi

log "=== Summary: ${FAILURES} failure(s) — ${RESULT} (${DURATION}s)"

# Build JSON state file
mkdir -p "$(dirname "$STATE_FILE")"
STEPS_JSON=$(printf '%s,' "${STEPS[@]}" | sed 's/,$//')

cat > "$STATE_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "host": "${HOST}",
  "trigger": "${TRIGGER}",
  "result": "${RESULT}",
  "failures": ${FAILURES},
  "duration_seconds": ${DURATION},
  "steps": [${STEPS_JSON}],
  "changes": "$(echo "$REPORT" | tr '\n' '|' | sed 's/"/\\"/g')"
}
EOF

# Build report
REPORT_MSG="GitLab Runner Reconcile — ${HOST}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Trigger: ${TRIGGER}
Result: $([ "$RESULT" = "success" ] && echo "success" || echo "${FAILURES} failure(s)")
Duration: ${DURATION}s

Steps:
${REPORT}"

if (( FAILURES == 0 )); then
  # Only send "recovered" notification on health-failure trigger, not timer
  if [[ "$TRIGGER" == "health-failure" ]]; then
    notify "GitLab Runner recovered on ${HOST}"
  fi
  # Always send the full report
  notify "$REPORT_MSG"
  exit 0
else
  notify "GitLab Runner reconciliation failed on ${HOST}: ${FAILURES} issue(s)"
  notify "$REPORT_MSG"
  exit 1
fi
