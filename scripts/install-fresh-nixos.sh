#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://gitlab.com/willisivali/nixos-infrastructure.git}"
REPO_DIR="${REPO_DIR:-$HOME/nixos-infrastructure}"
HOST="${HOST:-prague}"
BRANCH="${BRANCH:-main}"
TARGET_USER="${TARGET_USER:-ivali}"
NIX_FEATURES="nix-command flakes"

log() {
  printf '\n\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\n\033[1;33mWARN:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

run_nix() {
  nix --extra-experimental-features "$NIX_FEATURES" "$@"
}

require_nixos() {
  [ -f /etc/NIXOS ] || die "This installer must run on NixOS."
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
  [ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not with sudo. The script asks for sudo only when needed."
}

enable_nix_features_for_system() {
  log "Enabling flakes and nix-command for this fresh NixOS install"

  sudo mkdir -p /etc/nix
  if [ ! -f /etc/nix/nix.conf ]; then
    printf 'experimental-features = nix-command flakes\n' | sudo tee /etc/nix/nix.conf >/dev/null
  elif ! grep -Eq '(^| )experimental-features( |)=.*flakes' /etc/nix/nix.conf; then
    printf '\nexperimental-features = nix-command flakes\n' | sudo tee -a /etc/nix/nix.conf >/dev/null
  fi

  sudo systemctl restart nix-daemon.service 2>/dev/null || true
}

clone_or_update_repo() {
  log "Installing Git through a temporary Nix shell and fetching ${REPO_URL}"

  if [ -d "$REPO_DIR/.git" ]; then
    run_nix shell nixpkgs#git -c git -C "$REPO_DIR" fetch origin "$BRANCH"
    run_nix shell nixpkgs#git -c git -C "$REPO_DIR" checkout "$BRANCH"
    run_nix shell nixpkgs#git -c git -C "$REPO_DIR" pull --ff-only origin "$BRANCH"
  else
    mkdir -p "$(dirname "$REPO_DIR")"
    run_nix shell nixpkgs#git -c git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
  fi
}

copy_hardware_configuration() {
  log "Capturing this machine's generated hardware configuration"

  if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    warn "/etc/nixos/hardware-configuration.nix was not found; generating one now"
    sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
    install -m 0644 /tmp/hardware-configuration.nix "$REPO_DIR/hosts/hardware-configuration.nix"
  else
    install -m 0644 /etc/nixos/hardware-configuration.nix "$REPO_DIR/hosts/hardware-configuration.nix"
  fi
}

install_format_hook() {
  log "Installing automatic Nix formatter Git hook"

  install -m 0755 "$REPO_DIR/hooks/pre-commit" "$REPO_DIR/.git/hooks/pre-commit"
}

format_repo() {
  log "Formatting all Nix files"

  (
    cd "$REPO_DIR"
    run_nix fmt
  )
}

validate_config() {
  log "Validating the flake before switching"

  (
    cd "$REPO_DIR"
    run_nix flake check --print-build-logs
  )
}

switch_system() {
  log "Switching to the lean, tuned NixOS configuration for host ${HOST}"

  sudo nixos-rebuild switch \
    --option experimental-features "$NIX_FEATURES" \
    --flake "$REPO_DIR#$HOST"
}

post_install_notes() {
  cat <<EOF

Install completed.

Next steps:
  1. Reboot to load the tuned zen kernel and lean GNOME profile:
       sudo reboot

  2. Enroll Tailscale after reboot if needed:
       sudo tailscale up --ssh

  3. Commit the generated hardware file:
       cd "$REPO_DIR"
       git status
       git add hosts/hardware-configuration.nix
       git commit -m "Add hardware configuration for ${HOST}"
       git push

Notes:
  - This config uses linuxPackages_zen, zram, low-latency sysctl tuning, and a stripped GNOME module.
  - Open this repository in VS Code with:
       code "$REPO_DIR"
    or:
       edit-config
  - Grafana will be available locally after rebuild:
       http://localhost:3000
    Default local bootstrap login: admin / admin
  - Prometheus is bound locally:
       http://localhost:9090
  - Loki is bound locally:
       http://localhost:3100
  - The Git hook formats staged .nix files automatically on every commit.
  - VS Code settings remain mutable; only extensions are declarative.

Useful docs:
  - Grafana getting started:
      https://grafana.com/docs/grafana/latest/getting-started/
  - Prometheus getting started:
      https://prometheus.io/docs/tutorials/getting_started/
  - Loki configuration:
      https://grafana.com/docs/loki/latest/configuration/
  - Promtail installation/configuration:
      https://grafana.com/docs/loki/latest/send-data/promtail/installation/
EOF
}

main() {
  require_nixos
  enable_nix_features_for_system
  clone_or_update_repo
  copy_hardware_configuration
  install_format_hook
  format_repo
  validate_config
  switch_system
  post_install_notes
}

main "$@"
