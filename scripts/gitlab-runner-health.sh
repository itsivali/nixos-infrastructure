#!/usr/bin/env bash
#
# ==============================================================================
# Fleet GitLab Runner Health Monitor
# ==============================================================================
#
# File:
#   scripts/gitlab-runner-health.sh
#
# Purpose
# -------
# Performs a complete health assessment of the GitLab Runner and the GitOps
# repository it is expected to build.
#
# This script NEVER changes system state.
#
# It is purely observational.
#
# Recovery is handled by:
#
#   gitlab-runner-reconcile.service
#
# when this script exits non-zero.
#
# ==============================================================================
#
# Health Checks
#
#   ✓ gitlab-runner installed
#   ✓ gitlab-runner.service active
#   ✓ runner configuration exists
#   ✓ runner registered
#   ✓ GitLab reachable
#   ✓ GitOps repository reachable
#   ✓ GitOps branch exists
#   ✓ Local GitOps checkout (optional)
#   ✓ flake.nix exists
#   ✓ nix flake metadata
#   ✓ systemd healthy
#
# ==============================================================================

set -Eeuo pipefail

################################################################################
## Configuration
################################################################################

# shellcheck disable=SC2034
readonly VERSION="3.0.0"

readonly GITOPS_REPO="${GITOPS_REPO:-}"
readonly GITOPS_BRANCH="${GITOPS_BRANCH:-main}"
readonly HOST_NAME="${HOST_NAME:-unknown}"
readonly WORKTREE="${GITOPS_WORKTREE:-/var/lib/gitops}"

# GitLab Runner writes its config under the runner's $HOME. When this health
# service runs as root its own $HOME differs, so an explicit path is required.
readonly RUNNER_CONFIG="${GITLAB_RUNNER_CONFIG:-/var/lib/gitlab-runner/.gitlab-runner/config.toml}"

# GitLab API token for checking private repositories. Like the bot, accept the
# path to the sops-decrypted secret so the value is never baked into the unit.
readonly GITLAB_TOKEN="${GITLAB_TOKEN:-$(cat "${GITLAB_TOKEN_FILE:-/run/secrets/gitlab_token}" 2>/dev/null || true)}"

readonly CURL_TIMEOUT=10

################################################################################
## Statistics
################################################################################

TOTAL=0
PASS=0
WARN=0
FAIL=0

################################################################################
## Logging
################################################################################

timestamp() {

    date --iso-8601=seconds

}

log() {

    printf '[%s] %s\n' "$(timestamp)" "$*"

}

section() {

    log ""
    log "================================================================"
    log "$1"
    log "================================================================"

}

ok() {

    TOTAL=$((TOTAL+1))
    PASS=$((PASS+1))

    log "✓ $1"

}

warn() {

    TOTAL=$((TOTAL+1))
    WARN=$((WARN+1))

    log "⚠ $1"

}

fail() {

    TOTAL=$((TOTAL+1))
    FAIL=$((FAIL+1))

    log "✗ $1"

}

################################################################################
## Helpers
################################################################################

check_command() {

    command -v "$1" >/dev/null 2>&1

}

################################################################################
## GitLab URL
################################################################################

SERVER="$(
    printf '%s\n' "$GITOPS_REPO" |
        sed 's#^\(https://[^/]*\)/.*#\1#'
)"

################################################################################
## Header
################################################################################

section "Fleet GitLab Runner Health"

log "Host          : ${HOST_NAME}"
log "Repository    : ${GITOPS_REPO}"
log "Branch        : ${GITOPS_BRANCH}"
log "Worktree      : ${WORKTREE}"

################################################################################
## Required Commands
################################################################################

section "Required Commands"

for cmd in \
    git \
    gitlab-runner \
    curl \
    nix \
    systemctl
do

    if check_command "$cmd"
    then
        ok "$cmd installed"
    else
        fail "$cmd missing"
    fi

done

################################################################################
## Runner Service
################################################################################

section "GitLab Runner"

if systemctl is-enabled --quiet gitlab-runner.service
then
    ok "Runner enabled"
else
    warn "Runner not enabled"
fi

if systemctl is-active --quiet gitlab-runner.service
then
    ok "Runner active"
else
    fail "Runner inactive"
fi

################################################################################
## Runner Configuration
################################################################################

CONFIG="$RUNNER_CONFIG"

if [[ -f "$CONFIG" ]]
then
    ok "config.toml present"
else
    fail "config.toml missing"
fi

################################################################################
## Runner Registration
################################################################################

VERIFY_OUTPUT="$(
    gitlab-runner verify --config "$CONFIG" 2>&1 || true
)"

if echo "$VERIFY_OUTPUT" | grep -qiE "is (alive|valid)"
then
    ok "Runner verified"
else
    warn "Runner verification returned warnings"
fi

################################################################################
## GitLab Connectivity
################################################################################

section "GitLab Connectivity"

if curl \
    --silent \
    --fail \
    --location \
    --connect-timeout 5 \
    --max-time "$CURL_TIMEOUT" \
    "$SERVER" >/dev/null
then
    ok "GitLab reachable"
else
    fail "Cannot reach GitLab"
fi

################################################################################
## GitOps Repository
################################################################################

section "GitOps Repository"

if [[ -n "${GITLAB_TOKEN:-}" ]] && [[ "$GITOPS_REPO" =~ ^https://([^/]+)/(.+)$ ]]
then

    # Private repository: verify reachability through the GitLab API, which
    # accepts the same PRIVATE-TOKEN the CI pipeline uses.
    GITLAB_HOST="${BASH_REMATCH[1]}"
    GITLAB_PROJECT="$(
        printf '%s\n' "${BASH_REMATCH[2]}" |
            sed 's#/#%2F#g'
    )"

    if curl \
        --silent \
        --fail \
        --location \
        --connect-timeout 5 \
        --max-time "$CURL_TIMEOUT" \
        --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
        "https://${GITLAB_HOST}/api/v4/projects/${GITLAB_PROJECT}/repository/branches/${GITOPS_BRANCH}" \
        >/dev/null
    then

        ok "Repository reachable (via API)"

    else

        fail "Cannot access repository (API returned an error or the token is invalid)"

    fi

elif git ls-remote \
    --heads \
    "$GITOPS_REPO" \
    "$GITOPS_BRANCH" \
    >/dev/null 2>&1
then

    ok "Repository reachable"

else

    fail "Cannot access repository"

fi

################################################################################
## Local Worktree
################################################################################

if [[ -d "$WORKTREE" ]]
then

    ok "Worktree exists"

    if [[ -f "$WORKTREE/flake.nix" ]]
    then
        ok "flake.nix found"
    else
        fail "flake.nix missing"
    fi

    if [[ -f "$WORKTREE/flake.lock" ]]
    then
        ok "flake.lock found"
    else
        warn "flake.lock missing"
    fi

    if (
        cd "$WORKTREE"

        nix flake metadata >/dev/null
    )
    then

        ok "flake metadata OK"

    else

        fail "flake evaluation failed"

    fi

else

    warn "Local GitOps checkout missing"

fi

################################################################################
## Git Repository Integrity
################################################################################

if [[ -d "$WORKTREE/.git" ]]
then

    if (
        cd "$WORKTREE"

        git rev-parse HEAD >/dev/null
    )
    then
        ok "Git repository valid"
    else
        fail "Git repository corrupted"
    fi

fi

################################################################################
## Runner List
################################################################################

RUNNERS="$(
    gitlab-runner --log-format json list --config "$CONFIG" 2>&1 || true
)"

COUNT="$(
    printf '%s\n' "$RUNNERS" |
        grep -c '.*"Executor".*"URL".*' || true
)"

if (( COUNT > 0 ))
then

    ok "${COUNT} configured runner(s)"

else

    warn "No configured runners"

fi

################################################################################
## System State
################################################################################

STATE="$(
    systemctl is-system-running || true
)"

case "$STATE" in

    running)

        ok "System running"

        ;;

    degraded)

        warn "System degraded"

        ;;

    *)

        fail "System state: $STATE"

        ;;

esac

################################################################################
## Summary
################################################################################

section "Summary"

log "Host               : ${HOST_NAME}"
log "Repository         : ${GITOPS_REPO}"
log "Branch             : ${GITOPS_BRANCH}"

log ""

log "Checks             : ${TOTAL}"
log "Passed             : ${PASS}"
log "Warnings           : ${WARN}"
log "Failures           : ${FAIL}"

################################################################################
## Write JSON state
################################################################################

STATE_FILE="/var/lib/gitlab-runner/health-state.json"
mkdir -p "$(dirname "$STATE_FILE")"

cat > "$STATE_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "host": "${HOST_NAME}",
  "result": "$([ "$FAIL" -eq 0 ] && echo "healthy" || echo "unhealthy")",
  "checks": {
    "total": ${TOTAL},
    "pass": ${PASS},
    "warn": ${WARN},
    "fail": ${FAIL}
  },
  "details": []
}
EOF

################################################################################
## Exit
################################################################################

if (( FAIL == 0 ))
then

    log ""
    log "Fleet GitLab Runner HEALTHY"

    exit 0

fi

log ""
log "Fleet GitLab Runner UNHEALTHY"

exit 1
