#!/run/current-system/sw/bin/bash
# rebuild — system rebuild with real-time progress
#
# Usage: rebuild [flags]
#   Runs: fetch -> rebase -> hw-check -> hash-check -> eval gates -> nixos-rebuild switch

set -Eeuo pipefail

REPO_DIR="/home/ivali/nixos-infrastructure"
HOST="prague"

# -- Theme -------------------------------------------------------------------

BOLD="\033[1m"
DIM="\033[2m"
ITALIC="\033[3m"
UNDERLINE="\033[4m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
MAGENTA="\033[35m"
BLUE="\033[34m"
WHITE="\033[97m"
BG_GREEN="\033[42m"
BG_RED="\033[41m"
BG_BLUE="\033[44m"
RESET="\033[0m"

# -- Icons -------------------------------------------------------------------

ICON_GIT="📡"
ICON_SYNC="🔄"
ICON_HW="🔧"
ICON_GO="🦫"
ICON_EVAL="🔍"
ICON_FLAKE="❄️"
ICON_BUILD="🏗️"
ICON_FETCH="⬇️"
ICON_COPY="📦"
ICON_HOOK="⚙️"
ICON_CONF="📝"
ICON_SVC="🚀"
ICON_STOP="🛑"
ICON_START="▶️"
ICON_DONE="✅"
ICON_FAIL="❌"
ICON_WARN="⚠️"
ICON_ERR="💥"
ICON_HOURGLASS="⏳"
ICON_ROCKET="🚀"
ICON_SHIELD="🛡️"
ICON_CLOCK="⏱️"
ICON_DISK="💿"
ICON_NETWORK="🌐"

# -- Helpers -----------------------------------------------------------------

step() {
  echo ""
  echo -e "  ${CYAN}${BOLD}┌─ $*${RESET}"
}

substep() {
  echo -e "  ${DIM}│${RESET}  $*"
}

ok() {
  echo -e "  ${GREEN}${BOLD}│${RESET}  ${GREEN}✓${RESET}  $*"
}

warn() {
  echo -e "  ${YELLOW}${BOLD}│${RESET}  ${YELLOW}!${RESET}  $*"
}

fail() {
  echo -e "  ${RED}${BOLD}│${RESET}  ${RED}✗${RESET}  $*"
}

info() {
  echo -e "  ${DIM}│${RESET}     ${DIM}$*${RESET}"
}

section_done() {
  echo -e "  ${GREEN}${BOLD}└─── done${RESET}"
}

section_fail() {
  echo -e "  ${RED}${BOLD}└─── failed${RESET}"
}

divider() {
  echo ""
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

header_line() {
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

elapsed() {
  local s=$1
  printf "%dm%02ds" $((s/60)) $((s%60))
}

START=$SECONDS

# -- Header ------------------------------------------------------------------

echo ""
echo ""
echo -e "  ${WHITE}${BOLD}┌──────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${WHITE}${BOLD}│${RESET}  ${ICON_ROCKET}  ${BOLD}${WHITE}NixOS Rebuild${RESET}  ${DIM}—${RESET}  ${CYAN}${BOLD}${HOST}${RESET}  ${DIM}·${RESET}  ${ITALIC}main${RESET}"
echo -e "  ${WHITE}${BOLD}└──────────────────────────────────────────────────────────┘${RESET}"
echo ""
header_line

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 1: Git Fetch
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "${ICON_GIT}  Fetching from origin..."

if output=$(git -C "$REPO_DIR" fetch origin main 2>&1); then
  ok "Origin up to date"
  section_done
else
  fail "Fetch failed"
  info "$output"
  section_fail
  exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 2: Rebase
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "${ICON_SYNC}  Rebasing on origin/main..."

if output=$(git -C "$REPO_DIR" rebase origin/main 2>&1); then
  ok "Rebase clean"
  section_done
else
  warn "Rebase had conflicts or nothing to rebase"
  info "$output"
  section_done
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 3: Hardware UUID Check
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "${ICON_HW}  Validating hardware UUIDs..."

if output=$("$REPO_DIR/scripts/validate-hardware.sh" 2>&1); then
  ok "Hardware UUIDs verified"
  section_done
else
  fail "Hardware UUID check failed"
  info "$output"
  section_fail
  exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 4: Go Hash Check (conditional)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CHANGED_GO=$(git -C "$REPO_DIR" diff --name-only origin/main -- '*.go' 'go.mod' 'go.sum' 2>/dev/null | wc -l)

if [[ "$CHANGED_GO" -gt 0 ]]; then
  step "${ICON_GO}  Checking Go vendor hashes ${DIM}(${CHANGED_GO} files changed)${RESET}..."

  if output=$("$REPO_DIR/scripts/update-go-hashes.sh" --verify-only 2>&1); then
    ok "Vendor hashes valid"
    section_done
  else
    warn "Hash mismatch — updating..."
    if output=$("$REPO_DIR/scripts/update-go-hashes.sh" 2>&1); then
      ok "Vendor hashes updated"
      section_done
    else
      fail "Failed to update Go vendor hashes"
      info "$output"
      section_fail
      exit 1
    fi
  fi
else
  step "${ICON_GO}  Go vendor hashes ${DIM}(no changes, skipping)${RESET}"
  section_done
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 5: Nix Evaluation Gates
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "${ICON_EVAL}  Evaluating Nix configuration..."

if output=$(nix eval --json ".#nixosConfigurations.${HOST}.config.system.build.toplevel.name" 2>&1); then
  ok "Configuration evaluates cleanly"
  section_done
else
  fail "Nix evaluation failed — fix errors before rebuild"
  info "$output"
  section_fail
  exit 1
fi

step "${ICON_FLAKE}  Checking flake validity..."

if output=$(nix flake check --no-build 2>&1); then
  ok "Flake schema valid"
  section_done
else
  fail "Flake check failed — fix errors before rebuild"
  info "$output"
  section_fail
  exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 6: Build & Activate
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
header_line
echo ""
echo -e "  ${WHITE}${BOLD}┌──────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${WHITE}${BOLD}│${RESET}  ${ICON_BUILD}  ${BOLD}${WHITE}Building & Activating System${RESET}"
echo -e "  ${WHITE}${BOLD}└──────────────────────────────────────────────────────────┘${RESET}"
echo ""

# Prompt for sudo password early
sudo -v 2>/dev/null

# Run nixos-rebuild and process output in real-time
BUILD_EXIT=0
sudo nixos-rebuild switch --flake "${REPO_DIR}#${HOST}" --show-trace 2>&1 | while IFS= read -r line; do
  case "$line" in
    *"copying path"*)
      name=$(echo "$line" | sed "s/.*copying path '\(.*\)'.*/\1/" | sed "s|/nix/store/[a-z0-9]*-||" | cut -c1-60)
      echo -e "  ${DIM}│${RESET}  ${ICON_COPY}  ${DIM}${name}${RESET}"
      ;;
    *"fetching"*|*"downloading"*|*"unpacking"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_FETCH}  ${DIM}${line}${RESET}"
      ;;
    *" flakes:"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_NETWORK}  Resolving flake inputs..."
      ;;
    *"hierarchical fetching"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_NETWORK}  Fetching dependencies..."
      ;;
    *"computing new closure"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_HOURGLASS}  Computing new system closure..."
      ;;
    *"building the system configuration"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_BUILD}  Building system configuration..."
      ;;
    *"building '/nix/store"*)
      drv=$(echo "$line" | sed "s/.*building '\(.*\)'.*/\1/" | sed "s|/nix/store/[a-z0-9]*-||" | cut -c1-55)
      echo -e "  ${DIM}│${RESET}  ${ICON_HOOK}  ${DIM}${drv}${RESET}"
      ;;
    *"running patch"*|*"running configure"*|*"running build"*|*"running install"*|*"running fixup"*|*"running patchelf"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_HOOK}  ${DIM}${line}${RESET}"
      ;;
    *"activating the configuration"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_CONF}  ${BOLD}Activating new configuration...${RESET}"
      ;;
    *"setting up /etc..."*)
      echo -e "  ${DIM}│${RESET}  ${ICON_CONF}  Configuring /etc..."
      ;;
    *"reloading the following units"*|*"restarting the following units"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_SVC}  ${GREEN}Reloading services...${RESET}"
      ;;
    *"stopping the following units"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_STOP}  ${YELLOW}Stopping services...${RESET}"
      ;;
    *"starting the following units"*|*"the following new units"*started*)
      echo -e "  ${DIM}│${RESET}  ${ICON_START}  ${GREEN}Starting services...${RESET}"
      ;;
    *"error:"*|*"FAILED"*)
      echo -e "  ${DIM}│${RESET}  ${ICON_ERR}  ${RED}${line}${RESET}"
      ;;
  esac
done || BUILD_EXIT=$?

# If the rebuild exited with code 4, deployment-health failed (non-critical).
if [[ $BUILD_EXIT -eq 4 ]]; then
  warn "Deployment health check failed — non-critical, continuing"
  BUILD_EXIT=0
fi

echo ""

if [[ $BUILD_EXIT -eq 0 ]]; then
  ok "System rebuilt successfully"
else
  fail "Build failed — exit code: ${BUILD_EXIT}"
  exit 1
fi

# -- Summary -----------------------------------------------------------------

echo ""
header_line
echo ""

DURATION=$(( SECONDS - START ))

echo -e "  ${WHITE}${BOLD}┌──────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${WHITE}${BOLD}│${RESET}  ${ICON_DONE}  ${GREEN}${BOLD}Rebuild Complete${RESET}  ${DIM}·${RESET}  ${ICON_CLOCK}  ${DIM}$(elapsed $DURATION)${RESET}"
echo -e "  ${WHITE}${BOLD}└──────────────────────────────────────────────────────────┘${RESET}"
echo ""
