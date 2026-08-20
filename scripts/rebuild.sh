#!/run/current-system/sw/bin/bash
# rebuild — system rebuild with real-time progress
#
# Usage: rebuild [flags]
#   Runs: fetch -> rebase -> hw-check -> hash-check -> eval gates -> nixos-rebuild switch

set -Eeuo pipefail

REPO_DIR="/home/ivali/nixos-infrastructure"
HOST="prague"

# -- Helpers -----------------------------------------------------------------

BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
MAGENTA="\033[35m"
RESET="\033[0m"

step()  { echo -e "${CYAN}>>>${RESET} $*"; }
ok()    { echo -e "${GREEN}  ✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}  !${RESET} $*"; }
fail()  { echo -e "${RED}  ✗${RESET} $*"; }
info()  { echo -e "${DIM}    $*${RESET}"; }
divider() { echo -e "${DIM}──────────────────────────────────────────────${RESET}"; }

elapsed() {
  local s=$1
  printf "%dm%02ds" $((s/60)) $((s%60))
}

START=$SECONDS

# -- Header ------------------------------------------------------------------

echo ""
echo -e "${BOLD}NixOS Rebuild${RESET}  ${DIM}${HOST} . main${RESET}"
divider

# -- Step 1: Git fetch -------------------------------------------------------

step "Fetching origin..."
if output=$(git -C "$REPO_DIR" fetch origin main 2>&1); then
  ok "Fetch complete"
else
  fail "Fetch failed"
  echo "$output"
  exit 1
fi

# -- Step 2: Rebase ----------------------------------------------------------

step "Rebasing on origin/main..."
if output=$(git -C "$REPO_DIR" rebase origin/main 2>&1); then
  ok "Rebase complete"
else
  warn "Rebase had conflicts or nothing to rebase"
  info "$output"
fi

# -- Step 3: Hardware UUID check ---------------------------------------------

step "Validating hardware UUIDs..."
if output=$("$REPO_DIR/scripts/validate-hardware.sh" 2>&1); then
  ok "Hardware UUIDs valid"
else
  fail "Hardware UUID check failed"
  echo "$output"
  exit 1
fi

# -- Step 4: Go hash check (only if Go files changed) ------------------------

CHANGED_GO=$(git -C "$REPO_DIR" diff --name-only origin/main -- '*.go' 'go.mod' 'go.sum' 2>/dev/null | wc -l)
if [[ "$CHANGED_GO" -gt 0 ]]; then
  step "Go files changed [${CHANGED_GO}] -- checking vendor hashes..."
  if output=$("$REPO_DIR/scripts/update-go-hashes.sh" --verify-only 2>&1); then
    ok "Go vendor hashes valid"
  else
    warn "Hash mismatch -- updating..."
    if output=$("$REPO_DIR/scripts/update-go-hashes.sh" 2>&1); then
      ok "Go vendor hashes updated"
    else
      fail "Failed to update Go vendor hashes"
      echo "$output"
      exit 1
    fi
  fi
else
  info "No Go changes -- skipping hash check"
fi

# -- Step 5: Nix evaluation gates --------------------------------------------

step "Evaluating configuration..."
if output=$(nix eval --json ".#nixosConfigurations.${HOST}.config.system.build.toplevel.name" 2>&1); then
  ok "Nix evaluation passed"
else
  fail "Nix evaluation failed -- fix errors before rebuild"
  echo "$output"
  exit 1
fi

step "Checking flake validity..."
if output=$(nix flake check --no-build 2>&1); then
  ok "Flake check passed"
else
  fail "Flake check failed -- fix errors before rebuild"
  echo "$output"
  exit 1
fi

# -- Step 6: Build & activate ------------------------------------------------

divider
echo -e "${BOLD}Building system...${RESET}"
divider

# Prompt for sudo password early
sudo -v 2>/dev/null

# Run nixos-rebuild and process output in real-time
BUILD_EXIT=0
sudo nixos-rebuild switch --flake "${REPO_DIR}#${HOST}" --show-trace 2>&1 | while IFS= read -r line; do
  case "$line" in
    *"copying path"*)

      name=$(echo "$line" | sed "s/.*copying path '\\(.*\\)'.*/\\1/" | sed "s|/nix/store/[a-z0-9]*-||" | cut -c1-60)
      echo -e "  ${CYAN}copy${RESET}  ${DIM}${name}${RESET}"
      ;;
    *"fetching"*|*"downloading"*|*"unpacking"*)
      echo -e "  ${CYAN}fetch${RESET} ${DIM}${line}${RESET}"
      ;;
    *" flakes:"*)
      echo -e "  ${CYAN}flake${RESET} Resolving inputs..."
      ;;
    *"hierarchical fetching"*)
      echo -e "  ${CYAN}deps${RESET}  Fetching dependencies..."
      ;;
    *"computing new closure"*)
      echo -e "${YELLOW}  -->${RESET} Computing new system closure..."
      ;;
    *"building the system configuration"*)
      echo -e "${YELLOW}  -->${RESET} Building system configuration..."
      ;;
    *"building '/nix/store"*)
      drv=$(echo "$line" | sed "s/.*building '\\(.*\\)'.*/\\1/" | sed "s|/nix/store/[a-z0-9]*-||" | cut -c1-55)
      echo -e "  ${MAGENTA}build${RESET} ${drv}"
      ;;
    *"running patch"*|*"running configure"*|*"running build"*|*"running install"*|*"running fixup"*|*"running patchelf"*)
      echo -e "  ${MAGENTA}hook${RESET}  ${DIM}${line}${RESET}"
      ;;
    *"activating the configuration"*)
      echo -e "${GREEN}  -->${RESET} Activating new configuration..."
      ;;
    *"setting up /etc..."*)
      echo -e "  ${GREEN}etc${RESET}   Configuring /etc..."
      ;;
    *"reloading the following units"*|*"restarting the following units"*)
      echo -e "  ${GREEN}svc${RESET}   Reloading services..."
      ;;
    *"stopping the following units"*)
      echo -e "  ${YELLOW}svc${RESET}   Stopping services..."
      ;;
    *"starting the following units"*|*"the following new units"*started*)
      echo -e "  ${GREEN}svc${RESET}   Starting services..."
      ;;
    *"error:"*|*"FAILED"*)
      echo -e "  ${RED}ERR${RESET}  ${line}"
      ;;
  esac
done || BUILD_EXIT=$?

# If the rebuild exited with code 4, deployment-health failed (non-critical).
if [[ $BUILD_EXIT -eq 4 ]]; then
  warn "deployment-health check failed -- continuing anyway"
  BUILD_EXIT=0
fi

echo ""

if [[ $BUILD_EXIT -eq 0 ]]; then
  ok "System rebuilt successfully"
else
  fail "Build failed -- exit code: $BUILD_EXIT"
  exit 1
fi

# -- Done --------------------------------------------------------------------

divider
DURATION=$(( SECONDS - START ))
echo -e "${GREEN}${BOLD}Done${RESET}  ${DIM}$(elapsed $DURATION)${RESET}"
echo ""
