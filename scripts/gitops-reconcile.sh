#!/run/current-system/sw/bin/bash
# gitops-reconcile.sh — pull → build → switch → health → rollback on failure
#
# Run by systemd gitops-reconciler.service every 15 minutes.
# Uses a lock file so concurrent timer fires cannot race.

set -Eeuo pipefail

###########################################################################
# Resolve repo root regardless of working directory (systemd sets CWD to /)
###########################################################################

REPO_DIR="/home/ivali/nixos-infrastructure"
SCRIPTS_DIR="${REPO_DIR}/scripts"
NOTIFY="${SCRIPTS_DIR}/notify.sh"
HEALTH="${SCRIPTS_DIR}/deployment-health.sh"
ROLLBACK="${SCRIPTS_DIR}/rollback.sh"

HOST="prague"
BRANCH="main"
LOCK_FILE="/run/deploy.lock"

###########################################################################
# Helpers
###########################################################################

log() { echo "[$(date -Iseconds)] $*"; }

notify() {
  if [[ -x "$NOTIFY" ]]; then
    "$NOTIFY" "$1" || true
  fi
}

###########################################################################
# Lock — only one reconciliation at a time
###########################################################################

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "Another reconciliation already running — skipping."
  exit 0
fi

###########################################################################
# Repo sanity
###########################################################################

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  notify "❌ GitOps failure: repo missing on ${HOST}"
  log "Repo missing at ${REPO_DIR}"
  exit 1
fi

cd "$REPO_DIR"

###########################################################################
# Dirty-tree guard
###########################################################################

if ! git diff --quiet; then
  notify "⚠️ GitOps skipped: uncommitted local changes on ${HOST}"
  log "Working tree dirty — skipping."
  exit 1
fi

###########################################################################
# Fetch and compare
###########################################################################

log "Fetching origin..."
git fetch --prune origin

LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/${BRANCH}")"

log "LOCAL  = ${LOCAL}"
log "REMOTE = ${REMOTE}"

if [[ "$LOCAL" == "$REMOTE" ]]; then
  log "Already up-to-date."
  exit 0
fi

###########################################################################
# Capture rollback anchor before we touch anything
###########################################################################

CURRENT_GEN="$(
  nix-env --list-generations --profile /nix/var/nix/profiles/system \
    | tail -1 | awk '{print $1}'
)"
log "Current generation: ${CURRENT_GEN}"

# Also save the current SHA so we can show a precise changelog after pulling
OLD_SHA="$LOCAL"

###########################################################################
# Pull
###########################################################################

log "Pulling updates..."
git pull --ff-only origin "${BRANCH}"

SHORT_SHA="$(git rev-parse --short HEAD)"
log "Now at ${SHORT_SHA}"

# Human-readable list of every commit that just arrived
CHANGELOG="$(git log --oneline "${OLD_SHA}..HEAD")"

# Every file touched across those commits (deduplicated)
CHANGED_FILES="$(git diff --name-only "${OLD_SHA}..HEAD")"

###########################################################################
# Validate flake
###########################################################################

log "Running flake check..."
if ! nix flake check --show-trace; then
  notify "❌ Flake check failed on ${HOST} (${SHORT_SHA})"
  exit 1
fi

###########################################################################
# Build
###########################################################################

log "Building system..."
if ! nix build ".#nixosConfigurations.${HOST}.config.system.build.toplevel"; then
  notify "❌ Build failed on ${HOST} (${SHORT_SHA})"
  exit 1
fi

###########################################################################
# Activate
###########################################################################

log "Activating..."
if ! nixos-rebuild switch --flake ".#${HOST}" --show-trace; then
  notify "❌ Activation failed on ${HOST} (${SHORT_SHA})"
  exit 1
fi

###########################################################################
# Health gate
###########################################################################

log "Running health check..."
if ! "$HEALTH"; then
  notify "🚨 Health check FAILED on ${HOST} — rolling back"
  log "Initiating rollback..."
  "$ROLLBACK"
  exit 1
fi

###########################################################################
# Success
###########################################################################

NEW_GEN="$(
  nix-env --list-generations --profile /nix/var/nix/profiles/system \
    | tail -1 | awk '{print $1}'
)"

notify "✅ ${HOST} updated successfully

Generation    : ${CURRENT_GEN} → ${NEW_GEN}
Commit        : ${SHORT_SHA}
Branch        : ${BRANCH}
Time          : $(date -Iseconds)

Changes
───────
${CHANGELOG}

Files touched
─────────────
${CHANGED_FILES}"

log "Reconciliation complete."
