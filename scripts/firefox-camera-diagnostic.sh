#!/usr/bin/env bash
# firefox-camera-diagnostic.sh — Diagnose Firefox camera/mic access issues
#
# Usage:
#   firefox-camera-diagnostic.sh           # Human-readable output
#   firefox-camera-diagnostic.sh --json    # JSON output
#
# This script NEVER modifies state. Read-only diagnostics only.

set -Eeuo pipefail

JSON_OUTPUT=false
[[ "${1:-}" == "--json" ]] && JSON_OUTPUT=true

PASS=0
WARN=0
FAIL=0
CHECKS=()

check() {
  local name="$1" status="$2" message="$3"
  CHECKS+=("{\"name\":\"${name}\",\"status\":\"${status}\",\"message\":\"$(echo "$message" | sed 's/"/\\"/g')\"}")
  case "$status" in
    pass) PASS=$((PASS+1)) ;;
    warn) WARN=$((WARN+1)) ;;
    fail) FAIL=$((FAIL+1)) ;;
  esac
}

ok()   { check "$1" "pass" "$2"; }
warn() { check "$1" "warn" "$2"; }
fail() { check "$1" "fail" "$2"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ─── Firefox Enterprise Policy ──────────────────────────────────────────

echo "═══════════════════════════════════════════════════════════════"
echo "  Firefox Camera/Mic Diagnostic"
echo "═══════════════════════════════════════════════════════════════"
echo

echo "── Firefox Enterprise Policy ──"
# Check both Home Manager path and legacy /etc/firefox path
POLICY_PATHS=(
  "/etc/profiles/per-user/ivali/lib/firefox/distribution/policies.json"
  "/etc/firefox/policies/policies.json"
)
POLICY_FILE=""
for path in "${POLICY_PATHS[@]}"; do
  if [[ -f "$path" ]]; then
    POLICY_FILE="$path"
    break
  fi
done

if [[ -n "$POLICY_FILE" ]]; then
  ok "policy-file" "exists: $POLICY_FILE"
  if have jq; then
    if jq -e '.policies.Permissions.Camera' "$POLICY_FILE" >/dev/null 2>&1; then
      ok "policy-camera" "Permissions.Camera configured"
    else
      fail "policy-camera" "Permissions.Camera NOT found in policy"
    fi
    if jq -e '.policies.Permissions.Microphone' "$POLICY_FILE" >/dev/null 2>&1; then
      ok "policy-microphone" "Permissions.Microphone configured"
    else
      fail "policy-microphone" "Permissions.Microphone NOT found in policy"
    fi
  else
    warn "policy-parse" "jq not installed, cannot validate policy JSON"
  fi
else
  fail "policy-file" "NOT found at any expected path:"
  for path in "${POLICY_PATHS[@]}"; do
    echo "    - $path"
  done
fi

echo
echo "── Firefox Installation ──"
if have firefox; then
  FIREFOX_BIN="$(command -v firefox)"
  ok "firefox" "installed: $FIREFOX_BIN"
else
  fail "firefox" "not found in PATH"
fi

# Check if Firefox is a Nix wrapper (Home Manager)
if [[ -L "${FIREFOX_BIN:-/nonexistent}" ]]; then
  LINK_TARGET="$(readlink -f "$FIREFOX_BIN" 2>/dev/null || echo "")"
  if [[ "$LINK_TARGET" == *"/nix/store/"* ]]; then
    ok "firefox-nix" "Nix store path: ${LINK_TARGET:0:60}..."
    echo "  NOTE: Nix-wrapped Firefox reads policies from its distribution/"
    echo "        directory in the Nix store, NOT from /etc/firefox/policies/."
    echo "        Home Manager deploys policies via programs.firefox.policies."
  fi
fi

echo
echo "── PipeWire Camera Support ──"
if have wpctl; then
  ok "wpctl" "installed: $(wpctl --version 2>&1 | head -1)"
  if wpctl status 2>/dev/null | grep -qi "camera\|video"; then
    ok "wpctl-cameras" "camera/video nodes detected in wpctl status"
  else
    warn "wpctl-cameras" "no camera/video nodes visible in wpctl status"
  fi
else
  warn "wpctl" "not installed (PipeWire CLI not available)"
fi

if systemctl is-active pipewire.service >/dev/null 2>&1 || \
   systemctl --user is-active pipewire.service >/dev/null 2>&1; then
  ok "pipewire" "active"
else
  fail "pipewire" "not active — PipeWire must be running for camera/mic"
fi

echo
echo "── Video Device Nodes ──"
VIDEO_NODES=()
for dev in /dev/video*; do
  if [[ -e "$dev" ]]; then
    VIDEO_NODES+=("$dev")
  fi
done

if [[ ${#VIDEO_NODES[@]} -gt 0 ]]; then
  ok "video-nodes" "${#VIDEO_NODES[@]} device(s): ${VIDEO_NODES[*]}"
  for dev in "${VIDEO_NODES[@]}"; do
    PERMS="$(stat -c '%a %U:%G' "$dev" 2>/dev/null || echo "unknown")"
    if [[ "$PERMS" == *"666"* ]] || [[ "$PERMS" == *"660"* ]] || [[ "$PERMS" == *"$USER:"* ]]; then
      ok "video-perm" "$dev: $PERMS"
    else
      warn "video-perm" "$dev: $PERMS (may need group membership)"
    fi
  done
else
  fail "video-nodes" "no /dev/video* devices found"
  echo "  Possible causes:"
  echo "    - Camera not detected by kernel (check dmesg for uvcvideo)"
  echo "    - v4l2loopback module not loaded"
  echo "    - Camera hardware disabled in BIOS/UEFI"
fi

echo
echo "── XDG Desktop Portal ──"
if systemctl --user is-active xdg-desktop-portal.service >/dev/null 2>&1; then
  ok "xdg-portal" "active (user session)"
else
  warn "xdg-portal" "not active — portal may not be handling camera/mic requests"
fi

if systemctl --user is-active xdg-desktop-portal-gnome.service >/dev/null 2>&1; then
  ok "xdg-portal-gnome" "active (user session)"
else
  warn "xdg-portal-gnome" "not active — GNOME portal may not be available"
fi

echo
echo "── Firefox Profile Permissions ──"
PROFILE_DIR="${HOME}/.mozilla/firefox"
if [[ -d "$PROFILE_DIR" ]]; then
  ok "firefox-profile" "profile directory exists: $PROFILE_DIR"
  # Check for permission database (stores camera/mic grants/denials)
  PERM_DB="${PROFILE_DIR}/permissions.sqlite"
  if [[ -f "$PERM_DB" ]]; then
    ok "permissions-db" "permissions.sqlite exists"
    if have sqlite3; then
      # Check for camera/mic denials for meet.google.com
      DENIALS=$(sqlite3 "$PERM_DB" \
        "SELECT origin, permission FROM moz_perms WHERE (permission='camera' OR permission='microphone') AND origin LIKE '%google%' AND expireType=0;" 2>/dev/null || echo "")
      if [[ -n "$DENIALS" ]]; then
        warn "camera-denials" "Found camera/mic denials for Google sites in Firefox profile:"
        echo "$DENIALS" | while read -r line; do echo "    $line"; done
        echo "  FIX: Open Firefox → Settings → Privacy & Permissions → Camera/Microphone"
        echo "       → Remove google.com entries, then reload Google Meet"
      else
        ok "camera-denials" "no camera/mic denials found for Google sites"
      fi
    else
      warn "sqlite3" "not installed, cannot inspect permissions database"
    fi
  else
    warn "permissions-db" "permissions.sqlite not found (Firefox may not have been used yet)"
  fi
else
  warn "firefox-profile" "no Firefox profile directory at $PROFILE_DIR"
fi

echo
echo "── Kernel Camera Module ──"
if lsmod 2>/dev/null | grep -q "uvcvideo"; then
  ok "uvcvideo" "loaded"
else
  warn "uvcvideo" "not loaded — UVC webcam driver may not be available"
fi

if lsmod 2>/dev/null | grep -q "v4l2loopback"; then
  ok "v4l2loopback" "loaded"
else
  warn "v4l2loopback" "not loaded (optional — only needed for virtual cameras)"
fi

# ─── Summary ──────────────────────────────────────────────────────────────

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL"
echo "═══════════════════════════════════════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
  echo
  echo "FAILURES detected. Common fixes:"
  echo "  1. Ensure PipeWire is running: systemctl --user status pipewire"
  echo "  2. Ensure camera device exists: ls -la /dev/video*"
  echo "  3. Check Firefox about:policies for loaded policies"
  echo "  4. Clear stale permissions: Firefox → Settings → Privacy → Camera/Microphone"
fi

if [[ "$JSON_OUTPUT" == "true" ]]; then
  echo
  echo "["
  for i in "${!CHECKS[@]}"; do
    [[ "$i" -gt 0 ]] && echo ","
    echo "  ${CHECKS[$i]}"
  done
  echo "]"
fi
