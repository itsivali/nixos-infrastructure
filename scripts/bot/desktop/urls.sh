#!/usr/bin/env bash
# desktop/urls.sh — URL shortcuts and folder shortcuts for /open
#
# Dependencies: lib/desktop.sh (launch_app)
##############################################################################

# URL shortcuts: keyword → URL (opened in Firefox)
declare -A URL_SHORTCUTS=(
  ["github"]="https://github.com"
  ["gitlab"]="https://gitlab.com"
  ["chatgpt"]="https://chatgpt.com"
  ["reddit"]="https://reddit.com"
  ["youtube"]="https://youtube.com"
  ["gmail"]="https://mail.google.com"
  ["calendar"]="https://calendar.google.com"
  ["drive"]="https://drive.google.com"
  ["azure"]="https://portal.azure.com"
  ["portal"]="https://portal.azure.com"
  ["outlook"]="https://outlook.live.com"
  ["nixos"]="https://search.nixos.org"
  ["home-manager"]="https://nixos.wiki/wiki/Home_Manager"
  ["hm"]="https://nixos.wiki/wiki/Home_Manager"
  ["nixpkgs"]="https://search.nixos.org/packages"
  ["wiki"]="https://en.wikipedia.org"
  ["arch"]="https://wiki.archlinux.org"
  ["stackoverflow"]="https://stackoverflow.com"
  ["so"]="https://stackoverflow.com"
)

# Folder shortcuts: keyword → path (opened in Nautilus)
declare -A FOLDER_SHORTCUTS=(
  ["downloads"]="${HOME}/Downloads"
  ["home"]="${HOME}"
  ["desktop"]="${HOME}/Desktop"
  ["documents"]="${HOME}/Documents"
  ["music"]="${HOME}/Music"
  ["pictures"]="${HOME}/Pictures"
  ["videos"]="${HOME}/Videos"
  ["public"]="${HOME}/Public"
  ["templates"]="${HOME}/Templates"
  ["trash"]="${HOME}/.local/share/Trash"
  ["config"]="${HOME}/nixos-infrastructure"
  ["repo"]="${HOME}/nixos-infrastructure"
  ["nixos"]="${HOME}/nixos-infrastructure"
  ["infra"]="${HOME}/nixos-infrastructure"
)

# URL-encode a string for use in search queries.
# Usage: encoded=$(urlencode "nix flakes tutorial")
urlencode() {
  local string="$1"
  python3 -c "import urllib.parse; print(urllib.parse.quote('$string', safe=''))" 2>/dev/null || \
  printf '%s' "$string" | curl -Gso /dev/null -w '%{url_effective}' --data-urlencode @- '' 2>/dev/null | cut -c3-
}

# Open a URL in Firefox.
_open_url() {
  local chat="$1" url="$2"
  launch_app "$chat" "firefox --new-window ${url}"
}

# Open a folder in Nautilus.
_open_folder() {
  local chat="$1" path="$2"
  launch_app "$chat" "nautilus ${path}"
}
