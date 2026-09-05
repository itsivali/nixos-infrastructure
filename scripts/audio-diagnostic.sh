#!/usr/bin/env bash
# audio-diagnostic.sh — Diagnose PipeWire/WirePlumber/Firefox audio stack
#
# Usage:
#   audio-diagnostic.sh           # Human-readable output
#   audio-diagnostic.sh --json    # JSON output
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

# ─── PipeWire Core ───────────────────────────────────────────────────────

echo "═══════════════════════════════════════════════════════════════"
echo "  Audio Stack Diagnostic"
echo "═══════════════════════════════════════════════════════════════"
echo

echo "── PipeWire ──"
if have pipewire; then
  ok "pipewire" "installed: $(pipewire --version 2>&1 | head -1)"
else
  fail "pipewire" "not installed"
fi

if systemctl --user is-active pipewire.service >/dev/null 2>&1; then
  ok "pipewire.service" "active (user session)"
elif systemctl is-active pipewire.service >/dev/null 2>&1; then
  ok "pipewire.service" "active (system)"
else
  fail "pipewire.service" "not active"
fi

echo
echo "── PipeWire-Pulse (PulseAudio compat) ──"
if systemctl --user is-active pipewire-pulse.service >/dev/null 2>&1; then
  ok "pipewire-pulse" "active"
else
  warn "pipewire-pulse" "not active (PulseAudio clients may not work)"
fi

echo
echo "── WirePlumber ──"
if systemctl --user is-active wireplumber.service >/dev/null 2>&1; then
  ok "wireplumber" "active"
else
  fail "wireplumber" "not active (device routing unavailable)"
fi

echo
echo "── Default Audio Devices ──"
# wpctl status marks the default sink/source with '*' on the line's third
# column. Parse section-aware: the default is the '*' line between the
# "Sinks:" and "Sources:"/end markers. This is locale-independent.
wpctl_default() {
  local section="$1"
  wpctl status 2>/dev/null | sed -n "/${section}:/,/^ ├─/p" | grep -m1 '\*' || true
}
if have wpctl; then
  DEFAULT_SINK=$(wpctl_default "Sinks" | sed 's/^[[:space:]]*//;s/\*//' | xargs || true)
  DEFAULT_SOURCE=$(wpctl_default "Sources" | sed 's/^[[:space:]]*//;s/\*//' | xargs || true)
  if [[ -n "$DEFAULT_SINK" ]]; then
    ok "default-sink" "$DEFAULT_SINK"
  else
    warn "default-sink" "no default sink found"
  fi
  if [[ -n "$DEFAULT_SOURCE" ]]; then
    ok "default-source" "$DEFAULT_SOURCE"
  else
    warn "default-source" "no default source (microphone) found"
  fi
elif have pactl; then
  SINK=$(pactl info 2>/dev/null | grep "Default Sink" | cut -d: -f2 | xargs || true)
  SOURCE=$(pactl info 2>/dev/null | grep "Default Source" | cut -d: -f2 | xargs || true)
  if [[ -n "$SINK" ]]; then
    ok "default-sink" "$SINK"
  else
    warn "default-sink" "no default sink found"
  fi
  if [[ -n "$SOURCE" ]]; then
    ok "default-source" "$SOURCE"
  else
    warn "default-source" "no default source (microphone) found"
  fi
else
  warn "default-devices" "neither wpctl nor pactl available"
fi

echo
echo "── ALSA ──"
if have aplay; then
  CARD_COUNT=$(arecord -l 2>/dev/null | grep -c "^card" || true)
  ok "alsa-cards" "${CARD_COUNT} capture card(s) detected"
else
  warn "alsa-utils" "not installed"
fi

echo
echo "── Audio Sources (inputs) ──"
if have wpctl; then
  SOURCES=$(wpctl status 2>/dev/null | grep -E '^\s+[0-9]+\.' | head -5 || true)
  if [[ -n "$SOURCES" ]]; then
    ok "audio-sources" "$(echo "$SOURCES" | wc -l) source(s) listed"
  else
    warn "audio-sources" "no sources detected"
  fi
elif have pactl; then
  pactl list short sources 2>/dev/null | head -5 || true
fi

echo
echo "── Audio Sinks (outputs) ──"
if have wpctl; then
  SINKS=$(wpctl status 2>/dev/null | grep -E '^\s+[0-9]+\.' | head -5 || true)
  if [[ -n "$SINKS" ]]; then
    ok "audio-sinks" "$(echo "$SINKS" | wc -l) sink(s) listed"
  else
    warn "audio-sinks" "no sinks detected"
  fi
elif have pactl; then
  pactl list short sinks 2>/dev/null | head -5 || true
fi

echo
echo "── rtkit (realtime scheduling) ──"
if systemctl status rtkit-daemon >/dev/null 2>&1; then
  ok "rtkit" "active"
else
  warn "rtkit" "not active (audio may crackle under load)"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Firefox Audio Configuration"
echo "═══════════════════════════════════════════════════════════════"
echo

FIREFOX_PROFILE="${HOME}/.mozilla/firefox/ivali"

if [[ -d "$FIREFOX_PROFILE" ]]; then
  ok "firefox-profile" "$FIREFOX_PROFILE"
else
  warn "firefox-profile" "profile directory not found at expected path"
fi

# Check about:config preferences (from prefs.js if available)
PREFS_FILE="${FIREFOX_PROFILE}/prefs.js"
if [[ -f "$PREFS_FILE" ]]; then
  echo
  echo "── Critical WebRTC/Audio Preferences ──"
  for pref in \
    "media.webrtc.enabled" \
    "media.peerconnection.enabled" \
    "media.getusermedia.screensharing.enabled" \
    "media.getusermedia.microphone.enabled" \
    "media.audio.suspend_on_video_visibility.enabled" \
    "media.webrtc.hw.h264.enabled" \
    "media.hardware-video-decoding.enabled" \
    "widget.dmabuf.force-enabled" \
    "MOZ_ENABLE_WAYLAND"; do
    if grep -q "\"${pref}\"" "$PREFS_FILE" 2>/dev/null; then
      val=$(grep "\"${pref}\"" "$PREFS_FILE" | tail -1 | sed 's/.*= *//;s/[;,].*//')
      ok "pref:${pref}" "$val"
    else
      warn "pref:${pref}" "not set (using Firefox default)"
    fi
  done
else
  warn "prefs.js" "not found (Firefox may not have been run yet)"
fi

echo
echo "── Wayland Session ──"
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
  ok "session-type" "wayland"
else
  warn "session-type" "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}"
fi

if [[ "${MOZ_ENABLE_WAYLAND:-}" == "1" ]]; then
  ok "MOZ_ENABLE_WAYLAND" "1"
else
  warn "MOZ_ENABLE_WAYLAND" "not set"
fi

echo
echo "── XDG Portal ──"
if systemctl --user is-active xdg-desktop-portal.service >/dev/null 2>&1; then
  ok "xdg-desktop-portal" "active"
else
  warn "xdg-desktop-portal" "not active (screen sharing may not work)"
fi

if systemctl --user is-active xdg-desktop-portal-gnome.service >/dev/null 2>&1; then
  ok "xdg-desktop-portal-gnome" "active"
else
  warn "xdg-desktop-portal-gnome" "not active (GNOME portal backend missing)"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  SOPS Secrets"
echo "═══════════════════════════════════════════════════════════════"
echo

SOPS_KEY="${HOME}/.config/sops/age/keys.txt"
if [[ -f "$SOPS_KEY" ]]; then
  ok "sops-key" "$SOPS_KEY"
else
  fail "sops-key" "not found at $SOPS_KEY"
fi

if [[ -d /run/secrets ]]; then
  SECRET_COUNT=$(ls /run/secrets/ 2>/dev/null | wc -l)
  ok "sops-secrets" "$SECRET_COUNT secret(s) mounted at /run/secrets"
else
  warn "sops-secrets" "/run/secrets not mounted (secrets unavailable)"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Tailscale"
echo "═══════════════════════════════════════════════════════════════"
echo

if have tailscale; then
  TS_STATUS=$(tailscale status 2>/dev/null | head -1 || true)
  if [[ "$TS_STATUS" == *"Connected"* ]] || tailscale status --json 2>/dev/null | grep -q '"BackendState":"Running"'; then
    ok "tailscale" "connected"
    TS_IP=$(tailscale ip -4 2>/dev/null || true)
    [[ -n "$TS_IP" ]] && ok "tailscale-ip" "$TS_IP"
  else
    warn "tailscale" "not connected or not running"
  fi
else
  warn "tailscale" "not installed"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Summary"
echo "═══════════════════════════════════════════════════════════════"
echo
TOTAL=$((PASS + WARN + FAIL))
echo "  Total: ${TOTAL}  Pass: ${PASS}  Warn: ${WARN}  Fail: ${FAIL}"
echo

if [[ "$JSON_OUTPUT" == "true" ]]; then
  echo "{\"total\":${TOTAL},\"pass\":${PASS},\"warn\":${WARN},\"fail\":${FAIL},\"checks\":[$(IFS=,; echo "${CHECKS[*]}")]}"
fi

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
