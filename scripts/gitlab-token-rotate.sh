#!/usr/bin/env bash
#
# GitLab host token self-rotation
# ---------------------------------------------------------------------------
# Rotates the dedicated *host* GitLab personal access token
# (secrets/gitlab.yaml -> gitlab_token) before it expires, so the GitLab
# runner / GitOps automation never depend on an expired token.
#
# Behaviour
#   - Reads the current host token from $GITLAB_TOKEN_FILE.
#   - Queries GitLab for the token's expiry.
#   - If more than $DROP_DAYS_BEFORE days remain: exits without changes.
#   - Otherwise rotates via POST /personal_access_tokens/self/rotate
#     (requires the api or self_rotate scope), requesting a new expiry of
#     $NEW_TTL_DAYS days.
#   - Re-encrypts secrets/gitlab.yaml in a dedicated worktree, commits the
#     new token to the GitOps branch, then triggers the GitOps reconciler so
#     the host re-materialises the secret.
#
# This token is the *host* token, kept separate from the operator's glab CLI
# token, so rotating it never breaks interactive tooling.
#
set -euo pipefail

###############################################################################
# Configuration (overridable via environment for testing)
###############################################################################

API_BASE="${GITLAB_API_BASE:-https://gitlab.com/api/v4}"
TOKEN_FILE="${GITLAB_TOKEN_FILE:-/run/secrets/gitlab_token}"
REPO="${GITLAB_REPO:?GITLAB_REPO must be set}"
BRANCH="${GITLAB_BRANCH:-main}"
SOPS_FILE_REL="${SOPS_FILE_REL:-secrets/gitlab.yaml}"
AGE_KEY="${SOPS_AGE_KEY_FILE:-/home/ivali/.config/sops/age/keys.txt}"
DROP_DAYS_BEFORE="${DROP_DAYS_BEFORE:-7}"
NEW_TTL_DAYS="${NEW_TTL_DAYS:-30}"
DRY_RUN="${ROTATE_DRY_RUN:-0}"

# systemd StateDirectory may be colon-separated; take the first entry.
WORKTREE="${WORKTREE:-${STATE_DIRECTORY:-}}"
WORKTREE="${WORKTREE%%:*}"
WORKTREE="${WORKTREE:-/var/lib/gitlab-token-rotate}"

NOTIFY_SCRIPT="${NOTIFY_SCRIPT:-/var/lib/gitops/scripts/notify.sh}"

notify() {
  local msg="$1"
  echo "gitlab-token-rotate: $msg"
  if [[ "${NOTIFY_DISABLE:-0}" != "1" && -x "$NOTIFY_SCRIPT" ]]; then
    "$NOTIFY_SCRIPT" "$msg" || true
  fi
}

die() {
  notify "ERROR: $*"
  exit 1
}

###############################################################################
# Read the current host token
###############################################################################

[[ -r "$TOKEN_FILE" ]] || die "host token file not readable: $TOKEN_FILE"
TOKEN="$(cat "$TOKEN_FILE")"
[[ -n "$TOKEN" ]] || die "host token file is empty: $TOKEN_FILE"

api() {
  local method="$1" path="$2"
  shift 2
  curl -fsS -X "$method" \
    -H "PRIVATE-TOKEN: ${TOKEN}" \
    "$@" \
    "${API_BASE}${path}"
}

###############################################################################
# Inspect current token
###############################################################################

INFO="$(api GET /personal_access_tokens/self)" || die "failed to query token info (invalid/expired token?)"
EXPIRES_AT="$(printf '%s' "$INFO" | jq -r '.expires_at // empty')"
TOKEN_ID="$(printf '%s' "$INFO" | jq -r '.id // empty')"
[[ -n "$EXPIRES_AT" ]] || die "token has no expiry; refusing to rotate blindly"

NOW_EPOCH="$(date +%s)"
EXP_EPOCH="$(date -d "$EXPIRES_AT" +%s)"
DAYS_LEFT=$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))

echo "gitlab-token-rotate: token id=${TOKEN_ID} expires=${EXPIRES_AT} (${DAYS_LEFT}d left)"

if (( DAYS_LEFT > DROP_DAYS_BEFORE )); then
  echo "gitlab-token-rotate: more than ${DROP_DAYS_BEFORE}d remain; nothing to do"
  exit 0
fi

###############################################################################
# Rotate
###############################################################################

NEW_EXPIRY="$(date -d "+${NEW_TTL_DAYS} days" +%Y-%m-%d)"
echo "gitlab-token-rotate: rotating (new expiry ${NEW_EXPIRY})"

RESP="$(api POST /personal_access_tokens/self/rotate -d "expires_at=${NEW_EXPIRY}")" \
  || die "rotation request failed"
NEW_TOKEN="$(printf '%s' "$RESP" | jq -r '.token // empty')"
NEW_ID="$(printf '%s' "$RESP" | jq -r '.id // empty')"
[[ -n "$NEW_TOKEN" ]] || die "rotation response contained no token"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "gitlab-token-rotate: dry-run; rotated id=${NEW_ID} but not persisting"
  exit 0
fi

###############################################################################
# Persist in the dedicated worktree (re-encrypt sops, commit, push)
###############################################################################

if [[ ! -d "${WORKTREE}/.git" ]]; then
  echo "gitlab-token-rotate: cloning ${REPO} -> ${WORKTREE}"
  git clone --quiet "$REPO" "$WORKTREE" || die "clone failed"
fi

git -C "$WORKTREE" fetch --quiet origin "$BRANCH" || die "git fetch failed"
git -C "$WORKTREE" checkout --quiet -B "$BRANCH" "origin/${BRANCH}" || die "git checkout failed"

SOPS_FILE="${WORKTREE}/${SOPS_FILE_REL}"
[[ -f "$SOPS_FILE" ]] || die "sops file not found: $SOPS_FILE"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! SOPS_AGE_KEY_FILE="$AGE_KEY" sops --decrypt --output-type json "$SOPS_FILE" > "${TMP_DIR}/plain.json"; then
  die "sops decrypt failed"
fi
jq --arg t "$NEW_TOKEN" '.gitlab_token = $t' "${TMP_DIR}/plain.json" > "${TMP_DIR}/new.json"

if ! SOPS_AGE_KEY_FILE="$AGE_KEY" sops --encrypt \
  --input-type json --output-type yaml \
  --filename-override "$SOPS_FILE" \
  "${TMP_DIR}/new.json" > "${TMP_DIR}/gitlab.yaml"; then
  die "sops re-encrypt failed"
fi
mv "${TMP_DIR}/gitlab.yaml" "$SOPS_FILE"

git -C "$WORKTREE" add "$SOPS_FILE_REL"
if git -C "$WORKTREE" diff --cached --quiet; then
  echo "gitlab-token-rotate: no change to commit"
else
  GIT_AUTHOR_NAME="Willis Ivali" GIT_AUTHOR_EMAIL="itsivali@outlook.com" \
  GIT_COMMITTER_NAME="Willis Ivali" GIT_COMMITTER_EMAIL="itsivali@outlook.com" \
    git -C "$WORKTREE" commit --quiet -m "chore(secrets): rotate gitlab host token" \
    || die "git commit failed"
fi

if ! git -C "$WORKTREE" push --quiet origin "HEAD:${BRANCH}"; then
  die "git push failed (new token NOT persisted to git; runtime token already rotated)"
fi

###############################################################################
# Apply on the host: trigger the GitOps reconciler to re-materialise the secret
###############################################################################

if command -v systemctl >/dev/null 2>&1; then
  sudo /run/current-system/sw/bin/systemctl start gitops-reconciler.service \
    || notify "WARNING: could not trigger gitops-reconciler; secret will apply on next run"
fi

notify "Rotated GitLab host token (id ${TOKEN_ID} -> ${NEW_ID}), new expiry ${NEW_EXPIRY}; pushed to ${BRANCH}."
