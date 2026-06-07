#!/usr/bin/env bash
# install-fresh-nixos.sh
# Bootstrap a fresh NixOS machine from the willisivali/nixos-infrastructure flake.
#
# Run as your normal user (NOT root). sudo is called only when needed.
#
#   nix --extra-experimental-features "nix-command flakes" \
#     shell nixpkgs#curl --command bash -c \
#     'curl -fsSL https://gitlab.com/willisivali/nixos-infrastructure/-/raw/main/scripts/install-fresh-nixos.sh | bash'
#
# Override defaults via environment variables before running:
#   REPO_URL, GIT_PUSH_URL, REPO_DIR, HOST, BRANCH
set -euo pipefail

REPO_URL="${REPO_URL:-https://gitlab.com/willisivali/nixos-infrastructure.git}"
GIT_PUSH_URL="${GIT_PUSH_URL:-git@gitlab.com:willisivali/nixos-infrastructure.git}"
REPO_DIR="${REPO_DIR:-$HOME/nixos-infrastructure}"
HOST="${HOST:-prague}"
BRANCH="${BRANCH:-main}"
EXPECTED_USER="${EXPECTED_USER:-ivali}"
NIX_FEATURES="nix-command flakes"

# ── logging ────────────────────────────────────────────────────────────────────
log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ── nix wrappers ───────────────────────────────────────────────────────────────

# Wrap every plain `nix` call so --extra-experimental-features is always
# present — required when the script is piped through a fresh bash that
# hasn't read any nix.conf yet.
nix() {
  command nix --extra-experimental-features "$NIX_FEATURES" "$@"
}

# nix fmt and nix flake check both exec `git` internally (to resolve the repo
# root and respect .gitignore). On a fresh install git is not on PATH, so we
# enter a temporary shell that provides it before calling nix.
nix_with_git() {
  command nix --extra-experimental-features "$NIX_FEATURES" \
    shell nixpkgs#git --command \
    nix --extra-experimental-features "$NIX_FEATURES" "$@"
}

# ── steps ──────────────────────────────────────────────────────────────────────

require_nixos() {
  [[ -f /etc/NIXOS ]] || die "This script must run on NixOS."
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
  [[ "$(id -u)" -ne 0 ]] \
    || die "Run as your normal user, not root. The script calls sudo only when needed."
  [[ "$(id -un)" == "$EXPECTED_USER" ]] \
    || die "This flake configures the '$EXPECTED_USER' user. Log in as '$EXPECTED_USER' before running the installer."
}

enable_nix_features() {
  # /etc/nix is read-only on a fresh NixOS install — it is managed by the
  # Nix module system and cannot be written to with sudo tee.
  # Write to the user-level config instead; it is always writable and is
  # honoured by every subsequent nix invocation for this user.
  # Permanent system-level config is already declared in the flake:
  #   nix.settings.experimental-features = [ "nix-command" "flakes" ];
  log "Enabling nix-command + flakes (user config)"

  local conf_dir="$HOME/.config/nix"
  local conf="$conf_dir/nix.conf"
  mkdir -p "$conf_dir"

  if [[ ! -f "$conf" ]]; then
    printf 'experimental-features = nix-command flakes\n' > "$conf"
  elif ! grep -Eq '(^|[[:space:]])experimental-features[[:space:]]*=.*flakes' "$conf"; then
    printf '\nexperimental-features = nix-command flakes\n' >> "$conf"
  else
    log "experimental-features already present — skipping"
  fi

  # Also export NIX_CONFIG so the current piped-bash process picks it up
  # immediately, before nix-daemon re-reads anything from disk.
  export NIX_CONFIG="experimental-features = nix-command flakes"
}

clone_or_update_repo() {
  log "Fetching repo (via temporary git shell): ${REPO_URL}"

  if [[ -d "$REPO_DIR/.git" ]]; then
    nix shell nixpkgs#git --command git -C "$REPO_DIR" fetch --prune origin "$BRANCH"
    nix shell nixpkgs#git --command git -C "$REPO_DIR" checkout "$BRANCH"
    nix shell nixpkgs#git --command git -C "$REPO_DIR" merge --ff-only "origin/$BRANCH"
  else
    mkdir -p "$(dirname "$REPO_DIR")"
    nix shell nixpkgs#git --command git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
  fi

  nix shell nixpkgs#git --command git -C "$REPO_DIR" remote set-url --push origin "$GIT_PUSH_URL"
}

copy_hardware_config() {
  log "Capturing hardware configuration"

  local src="/etc/nixos/hardware-configuration.nix"
  local dst="$REPO_DIR/hosts/hardware-configuration.nix"

  if [[ ! -f "$src" ]]; then
    warn "$src not found — generating with nixos-generate-config"
    sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
    src="/tmp/hardware-configuration.nix"
  fi

  install -Dm0644 "$src" "$dst"
  log "Hardware config written to $dst"
}

install_format_hook() {
  log "Installing pre-commit formatter hook"
  local hook_src="$REPO_DIR/hooks/pre-commit"
  local hook_dst="$REPO_DIR/.git/hooks/pre-commit"
  if [[ -f "$hook_src" ]]; then
    install -m0755 "$hook_src" "$hook_dst"
  else
    warn "hooks/pre-commit not found in repo — skipping"
  fi
}

format_repo() {
  log "Formatting Nix files"
  # Must run inside a shell that has git on PATH (nix fmt calls git internally).
  ( cd "$REPO_DIR" && nix_with_git fmt )
}

validate_config() {
  # We do NOT run `nix flake check` here. On a fresh install it would:
  #   - try to build every packages.* output
  #   - require a clean git tree (dirty tree = instant failure)
  #   - evaluate checks.* which forces a full system build
  #   - evaluate nixosTests.* which requires QEMU
  #
  # Instead we evaluate only the target host's toplevel .drv path.
  # This fully type-checks the NixOS config (catches missing modules,
  # list-vs-string type errors, undefined options, etc.) without
  # building anything or caring about a dirty tree.
  log "Evaluating nixosConfigurations.${HOST} (dry-run, no build)"
  local drv
  drv=$(
    cd "$REPO_DIR"
    nix_with_git eval --raw \
      ".#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath"
  )
  log "Config evaluates cleanly → ${drv}"
}

switch_system() {
  log "Running nixos-rebuild switch → ${HOST}"
  sudo nixos-rebuild switch \
    --option experimental-features "$NIX_FEATURES" \
    --flake "$REPO_DIR#$HOST"
}

post_install_notes() {
  cat <<EOF

════════════════════════════════════════
  Install complete ✓
════════════════════════════════════════

Next steps
──────────
1. Reboot to load the zen kernel and lean GNOME profile:
     sudo reboot

2. After reboot, bring up Tailscale:
     sudo tailscale up --ssh

3. Commit the generated hardware file:
     cd "$REPO_DIR"
     git add hosts/hardware-configuration.nix
     git commit -m "chore: add hardware configuration for ${HOST}"
     git push

4. Test GitLab SSH:
     ssh -T git@gitlab.com

5. After the hardware file is pushed, enable system.autoUpgrade in:
     hosts/laptop.nix

Local services (after reboot)
──────────────────────────────
  Grafana    http://localhost:3000   (admin / admin on first boot)
  Prometheus http://localhost:9090
  Loki       http://localhost:3100

Open config in your editor:
  code "$REPO_DIR"   or   edit-config

Docs
────
  Grafana    https://grafana.com/docs/grafana/latest/getting-started/
  Prometheus https://prometheus.io/docs/tutorials/getting_started/
  Loki       https://grafana.com/docs/loki/latest/configuration/
  Alloy      https://grafana.com/docs/alloy/latest/
EOF
}

main() {
  require_nixos
  enable_nix_features
  clone_or_update_repo
  copy_hardware_config
  install_format_hook
  format_repo
  validate_config
  switch_system
  post_install_notes
}

main "$@"
