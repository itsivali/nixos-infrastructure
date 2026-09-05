#!/run/current-system/sw/bin/bash
# cache-stats — Display binary cache hit/miss statistics
#
# Usage: cache-stats
# Shows cache performance metrics for the local binary cache

set -euo pipefail

# Colors
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
WHITE="\033[97m"
RESET="\033[0m"

# Icons
ICON_CACHE="📦"

echo ""
echo -e "  ${WHITE}${BOLD}┌──────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${WHITE}${BOLD}│${RESET}  ${ICON_CACHE}  ${BOLD}${WHITE}Binary Cache Statistics${RESET}"
echo -e "  ${WHITE}${BOLD}└──────────────────────────────────────────────────────────┘${RESET}"
echo ""

# Local file cache stats
LOCAL_CACHE="/nix/var/nix/go-binary-cache"
if [[ -d "$LOCAL_CACHE" ]]; then
  echo -e "  ${CYAN}${BOLD}Local File Cache${RESET}"
  echo -e "  ${DIM}├──${RESET} Path: ${LOCAL_CACHE}"
  
  # Count entries
  ENTRY_COUNT=$(find "$LOCAL_CACHE" -name "*.nar" 2>/dev/null | wc -l)
  echo -e "  ${DIM}├──${RESET} Entries: ${ENTRY_COUNT}"
  
  # Calculate size
  CACHE_SIZE=$(du -sh "$LOCAL_CACHE" 2>/dev/null | cut -f1)
  echo -e "  ${DIM}└──${RESET} Size: ${CACHE_SIZE}"
  echo ""
fi

# Substituter configuration
echo -e "  ${CYAN}${BOLD}Configured Substituters${RESET}"
nix show-config --json 2>/dev/null | jq -r '.substituters[]?' 2>/dev/null | while read -r sub; do
  echo -e "  ${DIM}├──${RESET} ${sub}"
done
echo ""

# Recent build performance
echo -e "  ${CYAN}${BOLD}Recent Build Performance${RESET}"
echo -e "  ${DIM}├──${RESET} Last rebuild duration: $(last-rebuild-duration 2>/dev/null || echo 'N/A')"
echo -e "  ${DIM}└──${RESET} Cache hit rate: $(cache-hit-rate 2>/dev/null || echo 'N/A')"
echo ""

# Recommendations
echo -e "  ${CYAN}${BOLD}Recommendations${RESET}"
if [[ ${ENTRY_COUNT:-0} -lt 10 ]]; then
  echo -e "  ${DIM}├──${RESET} ${YELLOW}Cache is warming up. First rebuild will populate cache.${RESET}"
fi

echo -e "  ${DIM}└──${RESET} ${GREEN}Run 'nix copy --to <binary-cache-url> <pkg>' to manually cache packages${RESET}"
echo ""
