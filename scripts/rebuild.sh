#!/run/current-system/sw/bin/bash
# rebuild — pretty system rebuild with step-by-step output
#
# Usage: rebuild [flags]
#   Runs: fetch → rebase → hw-check → hash-check → nixos-rebuild switch

set -Eeuo pipefail

REPO_DIR="/home/ivali/nixos-infrastructure"
HOST="prague"

# ── Helpers ────────────────────────────────────────────────────────────────

BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

step()  { echo -e "${CYAN}▸${RESET} $*"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $*"; }
fail()  { echo -e "${RED}✗${RESET} $*"; }
info()  { echo -e "${DIM}  $*${RESET}"; }
lock()  { echo -e "${YELLOW}  $*${RESET}"; }

divider() {
  echo -e "${DIM}──────────────────────────────────────────────${RESET}"
}

elapsed() {
  local s=$1
  printf "%dm%02ds" $((s/60)) $((s%60))
}

START=$SECONDS

# ── Header ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD} NixOS Rebuild${RESET}  ${DIM}prague · main${RESET}"
divider

# ── Step 1: Git fetch ─────────────────────────────────────────────────────

step " Fetching origin..."
if output=$(git -C "$REPO_DIR" fetch origin main 2>&1); then
  ok "Fetch complete"
else
  fail "Fetch failed"
  echo "$output"
  exit 1
fi

# ── Step 2: Rebase ────────────────────────────────────────────────────────

step " Rebasing on origin/main..."
if output=$(git -C "$REPO_DIR" rebase origin/main 2>&1); then
  ok "Rebase complete"
else
  warn "Rebase had conflicts or nothing to rebase"
  info "$output"
fi

# ── Step 3: Hardware UUID check ───────────────────────────────────────────

step " Validating hardware UUIDs..."
if output=$("$REPO_DIR/scripts/validate-hardware.sh" 2>&1); then
  ok "Hardware UUIDs valid"
else
  fail "Hardware UUID check failed"
  echo "$output"
  exit 1
fi

# ── Step 4: Go hash check (only if Go files changed) ─────────────────────

CHANGED_GO=$(git -C "$REPO_DIR" diff --name-only origin/main -- '*.go' 'go.mod' 'go.sum' 2>/dev/null | wc -l)
if [[ "$CHANGED_GO" -gt 0 ]]; then
  step " Go files changed (${CHANGED_GO}) — checking vendor hashes..."
  if output=$("$REPO_DIR/scripts/update-go-hashes.sh" --verify-only 2>&1); then
    ok "Go vendor hashes valid"
  else
    warn "Hash mismatch — updating..."
    if output=$("$REPO_DIR/scripts/update-go-hashes.sh" 2>&1); then
      ok "Go vendor hashes updated"
    else
      fail "Failed to update Go vendor hashes"
      echo "$output"
      exit 1
    fi
  fi
else
  info "No Go changes — skipping hash check"
fi

# ── Step 5: Build & activate ──────────────────────────────────────────────

divider
lock "  Authorizing..."
step " Building and activating..."
echo ""
if sudo nixos-rebuild switch --flake "${REPO_DIR}#${HOST}" --show-trace 2>&1 | tail -5; then
  echo ""
  ok "System rebuilt successfully"
else
  echo ""
  fail "Build failed"
  exit 1
fi

# ── Done ──────────────────────────────────────────────────────────────────

divider
DURATION=$(( SECONDS - START ))
echo -e "${GREEN}${BOLD} Done${RESET}  ${DIM}$(elapsed $DURATION)${RESET}"
echo ""
