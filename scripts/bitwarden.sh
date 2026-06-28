#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/bitwarden"
SESSION_FILE="$CACHE_DIR/session"

mkdir -p "$CACHE_DIR"

status_json() { bw status; }
status_field() { status_json | jq -r ".$1"; }

load_session() {
  [[ -f "$SESSION_FILE" ]] || return 1
  export BW_SESSION="$(<"$SESSION_FILE")"
}

save_session() {
  printf "%s" "$BW_SESSION" > "$SESSION_FILE"
  chmod 600 "$SESSION_FILE"
}

unlock() {
  if [[ "$(status_field status)" == "unauthenticated" ]]; then
    echo "Not logged in. Run: bw login"
    exit 1
  fi
  export BW_SESSION="$(bw unlock --raw)"
  save_session
  echo "Bitwarden unlocked."
}

lock() {
  bw lock >/dev/null 2>&1 || true
  rm -f "$SESSION_FILE"
  unset BW_SESSION || true
  echo "Bitwarden locked."
}

sync_bw() { load_session || true; bw sync; }

doctor() {
  command -v bw >/dev/null || { echo "Missing bw"; exit 1; }
  command -v jq >/dev/null || { echo "Missing jq"; exit 1; }
  echo "Status: $(status_field status)"
  [[ -f "$SESSION_FILE" ]] && echo "Cached session: yes" || echo "Cached session: no"
}

get_item() {
  load_session || true
  bw get item "$1"
}

case "${1:-help}" in
  unlock) unlock ;;
  lock) lock ;;
  status) status_json | jq ;;
  sync) sync_bw ;;
  doctor) doctor ;;
  session) load_session && echo "$BW_SESSION" ;;
  get)
    [[ $# -ge 2 ]] || { echo "Usage: $0 get <item>"; exit 1; }
    get_item "$2"
    ;;
  clear)
    rm -f "$SESSION_FILE"
    echo "Session cache cleared."
    ;;
  help|*)
cat <<EOF
Usage: bitwarden.sh <command>

Commands:
  unlock   Unlock vault and cache session
  lock     Lock vault and clear cache
  status   Show bw status
  sync     Sync vault
  doctor   Verify installation
  session  Print cached session
  get      Get item by id/name
  clear    Remove cached session
EOF
;;
esac
