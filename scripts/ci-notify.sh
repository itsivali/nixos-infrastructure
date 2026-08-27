#!/run/current-system/sw/bin/bash
# ci-notify.sh — send email notification after CI passes on main
#
# Triggered by GitLab CI after all gates pass on a push/merge to main.
# Sends a formatted email via notify.sh with:
#   - What changed (commit message, type, description)
#   - MR description (if available)
#   - Files changed with stats
#   - Pipeline status and link
#
# Environment: GitLab CI predefined variables.

set -euo pipefail

# ── GitLab CI variables ────────────────────────────────────────────────────
COMMIT_SHA="${CI_COMMIT_SHA:-unknown}"
COMMIT_SHORT="${COMMIT_SHA:0:7}"
COMMIT_MSG="${CI_COMMIT_MESSAGE:-no message}"
COMMIT_AUTHOR="${CI_COMMIT_AUTHOR:-unknown}"
COMMIT_BRANCH="${CI_COMMIT_BRANCH:-unknown}"
PROJECT_URL="${CI_PROJECT_URL:-}"
PIPELINE_ID="${CI_PIPELINE_ID:-}"
PIPELINE_URL="${PROJECT_URL}/-/pipelines/${PIPELINE_ID}"
COMMIT_URL="${PROJECT_URL}/-/commit/${COMMIT_SHA}"

# MR variables (only available when pipeline is from MR merge)
MR_TITLE="${CI_MERGE_REQUEST_TITLE:-}"
MR_DESC="${CI_MERGE_REQUEST_DESCRIPTION:-}"
MR_IID="${CI_MERGE_REQUEST_IID:-}"
MR_URL="${PROJECT_URL}/-/merge_requests/${MR_IID}"

# Email subject line is derived from the first line of the commit message
# (handled by notify.sh automatically)

# ── Parse commit message ───────────────────────────────────────────────────
# Expected format: type(scope): description
# Types: feat, fix, module, security, arch, docs, test, chore
TYPE=""
DESCRIPTION="${COMMIT_MSG}"

if [[ "${COMMIT_MSG}" =~ ^([a-z]+)(\(.+\))?:\ (.+)$ ]]; then
  TYPE="${BASH_REMATCH[1]}"
  DESCRIPTION="${BASH_REMATCH[3]}"
fi

# ── Determine what was wrong / what was fixed ──────────────────────────────
WHAT_BROKEN=""
WHAT_FIXED=""

case "${TYPE}" in
  feat)
    WHAT_BROKEN="Nothing was broken. This was a new capability."
    WHAT_FIXED="${DESCRIPTION}"
    ;;
  fix)
    WHAT_BROKEN="${DESCRIPTION}"
    WHAT_FIXED="Applied fix via this change."
    ;;
  module)
    WHAT_BROKEN="Missing or incomplete module configuration."
    WHAT_FIXED="${DESCRIPTION}"
    ;;
  security)
    WHAT_BROKEN="${DESCRIPTION}"
    WHAT_FIXED="Security hardening applied."
    ;;
  arch)
    WHAT_BROKEN="Architectural concern identified."
    WHAT_FIXED="${DESCRIPTION}"
    ;;
  *)
    WHAT_BROKEN="Not specified."
    WHAT_FIXED="${DESCRIPTION}"
    ;;
esac

# ── Get diff stat ──────────────────────────────────────────────────────────
DIFF_STAT=""
if git rev-parse HEAD~1 >/dev/null 2>&1; then
  DIFF_STAT=$(git diff --stat HEAD~1 HEAD 2>/dev/null || echo "Unable to retrieve diff stat")
else
  DIFF_STAT="Initial commit — no parent to compare"
fi

FILES_CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l || echo "0")
INSERTIONS=0
DELETIONS=0
if git diff --shortstat HEAD~1 HEAD 2>/dev/null | grep -q "insertion"; then
  INSERTIONS=$(git diff --shortstat HEAD~1 HEAD 2>/dev/null | grep -oP '\d+(?= insertion)' || echo "0")
fi
if git diff --shortstat HEAD~1 HEAD 2>/dev/null | grep -q "deletion"; then
  DELETIONS=$(git diff --shortstat HEAD~1 HEAD 2>/dev/null | grep -oP '\d+(?= deletion)' || echo "0")
fi

# ── Get recent commits (last 5) for context ────────────────────────────────
RECENT_COMMITS=""
if git rev-parse HEAD~5 >/dev/null 2>&1; then
  RECENT_COMMITS=$(git log --oneline -5 HEAD 2>/dev/null || echo "")
else
  RECENT_COMMITS=$(git log --oneline HEAD 2>/dev/null || echo "")
fi

# ── Build email body ───────────────────────────────────────────────────────
TIMESTAMP=$(date -Iseconds)

# MR section (if this was an MR merge)
MR_SECTION=""
if [[ -n "${MR_IID}" ]]; then
  MR_SECTION="
Merge Request
-------------
${MR_TITLE} (!${MR_IID})
${MR_URL}"

  if [[ -n "${MR_DESC}" ]]; then
    MR_SECTION="${MR_SECTION}

Description
-----------
${MR_DESC}"
  fi
fi

BODY="Ivali Flow — Repository Change Report

Repository
----------
nixos-infrastructure
GitLab: ${PROJECT_URL}

Change
------
Type: ${TYPE:-unknown}
Author: ${COMMIT_AUTHOR}
Branch: ${COMMIT_BRANCH}
Commit: ${COMMIT_SHORT}
Commit URL: ${COMMIT_URL}
Pipeline: ${PIPELINE_URL}
Timestamp: ${TIMESTAMP}
${MR_SECTION}

What Changed
------------
${DESCRIPTION}

What Was Broken
---------------
${WHAT_BROKEN}

What Was Fixed
--------------
${WHAT_FIXED}

Files Changed
-------------
${DIFF_STAT}

Summary
-------
${FILES_CHANGED} files changed, ${INSERTIONS} insertions(+), ${DELETIONS} deletions(-)

Recent Commits
--------------
${RECENT_COMMITS}

Pipeline
--------
All CI jobs passed. Change is ready for GitOps reconciliation."

# ── Send via notify.sh ─────────────────────────────────────────────────────
NOTIFY_SCRIPT="$(dirname "$0")/notify.sh"

if [[ ! -x "${NOTIFY_SCRIPT}" ]]; then
  echo "ci-notify.sh: notify.sh not found at ${NOTIFY_SCRIPT}" >&2
  exit 1
fi

# Use notify.sh directly — no dedup, each commit gets its own email
"${NOTIFY_SCRIPT}" "${BODY}" || echo "ci-notify.sh: email send failed (non-fatal)" >&2
