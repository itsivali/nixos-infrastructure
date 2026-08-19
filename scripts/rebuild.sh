#!/run/current-system/sw/bin/bash
# rebuild — pretty system rebuild with animated progress bar
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

divider() {
  echo -e "${DIM}──────────────────────────────────────────────${RESET}"
}

elapsed() {
  local s=$1
  printf "%dm%02ds" $((s/60)) $((s%60))
}

# ── Progress bar ──────────────────────────────────────────────────────────

render_bar() {
  local pct=$1 label=$2 icon=$3 color=$4
  local cols="${COLUMNS:-80}"
  local width=$((cols - 20))
  [[ $width -lt 20 ]] && width=40
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  local bar=""
  for ((i = 0; i < filled; i++)); do bar+="━"; done
  for ((i = 0; i < empty; i++)); do bar+="─"; done
    printf "\r${color} ${bar} ${icon} %3d%%  %s${RESET}" "$pct" "$label"
}

# Stages: icon, label, color
STAGES_ICONS=( "󰓚" "󰓚" "󰓚" "󰙍" "󰙍" "󰖿" )
STAGES_LABELS=( "Fetching" "Rebasing" "Validating" "Building" "Activating" "Complete" )
STAGES_COLORS=( "$CYAN" "$CYAN" "$YELLOW" "$YELLOW" "$GREEN" "$GREEN" )
NUM_STAGES=${#STAGES_LABELS[@]}

CURRENT_STAGE=0

show_progress() {
  local stage=$1
  if [[ $stage -gt $NUM_STAGES ]]; then stage=$NUM_STAGES; fi
  if [[ $stage -ne $CURRENT_STAGE ]]; then
    CURRENT_STAGE=$stage
  fi
  local pct=$((CURRENT_STAGE * 100 / NUM_STAGES))
  render_bar "$pct" "${STAGES_LABELS[$CURRENT_STAGE]}" "${STAGES_ICONS[$CURRENT_STAGE]}" "${STAGES_COLORS[$CURRENT_STAGE]}"
}

advance_stage() {
  show_progress $((CURRENT_STAGE + 1))
}

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
  step " Go files changed [${CHANGED_GO}] — checking vendor hashes..."
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

  show_progress 0

REBUILD_LOG=$(mktemp)
EXIT_CODE=0

sudo nixos-rebuild switch --flake "${REPO_DIR}#${HOST}" --show-trace \
  2>"$REBUILD_LOG" | while IFS= read -r line; do
  case "$line" in
    *"Fingerprint mismatch"* | *"error:"* | *"FAILED"*)
      advance_stage
      ;;
    *"building the system configuration"* | *"computing new closure"*)
      show_progress 4
      ;;
    *"activating the configuration"*)
      show_progress 5
      ;;
    *"reloading the following units"* | *"restarting the following units"* | \
    *"stopping the following units"* | *"starting the following units"* | \
    *"the following new units were started"*)
      advance_stage
      ;;
    *" flakes:"* | *"hierarchical fetching"* | *"copying path"* | \
    *"downloading"* | *"fetching"* | *"unpacking"* | *"unpacking packages"*)
      show_progress 1
      ;;
  esac
done || EXIT_CODE=$?

# Show build errors if any
if [[ -s "$REBUILD_LOG" ]]; then
  echo ""
  fail "Build errors:"
  cat "$REBUILD_LOG"
fi
rm -f "$REBUILD_LOG"

echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
  ok "System rebuilt successfully"
else
  fail "Build failed — exit code: $EXIT_CODE"
  exit 1
fi

# ── Done ──────────────────────────────────────────────────────────────────

divider
DURATION=$(( SECONDS - START ))
echo -e "${GREEN}${BOLD} Done${RESET}  ${DIM}$(elapsed $DURATION)${RESET}"
echo ""
