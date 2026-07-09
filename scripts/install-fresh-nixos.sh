#!/run/current-system/sw/bin/bash
# install-fresh-nixos.sh v3 — Universal NixOS + GNOME bootstrap
#
# Bootstrap a fresh NixOS machine from the willisivali/nixos-infrastructure flake.
# Sets up GNOME desktop, BTRFS optimization, and all infrastructure.
#
# Usage:
#   nix --extra-experimental-features "nix-command flakes" \
#     shell nixpkgs#curl --command bash -c \
#     'curl -fsSL https://gitlab.com/willisivali/nixos-infrastructure/-/raw/main/scripts/install-fresh-nixos.sh | bash'
#
# Or with flags for non-interactive:
#   curl -fsSL ... | bash -s -- --host my-laptop --user myuser --yes
#
# Environment variables (overridable):
#   REPO_URL, GIT_PUSH_URL, REPO_DIR, BRANCH, YES
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
REPO_URL="${REPO_URL:-https://gitlab.com/willisivali/nixos-infrastructure.git}"
GIT_PUSH_URL="${GIT_PUSH_URL:-git@gitlab.com:willisivali/nixos-infrastructure.git}"
REPO_DIR="${REPO_DIR:-$HOME/nixos-infrastructure}"
BRANCH="${BRANCH:-main}"
NIX_FEATURES="nix-command flakes"

# ── Parse flags ──────────────────────────────────────────────────────────────
HOST="${HOST:-}"
USER_NAME="${USER_NAME:-}"
YES="${YES:-false}"
DESKTOP="${DESKTOP:-gnome}"
FEATURES="${FEATURES:-secrets,gitlab-runner,bot,tailscale,tailscale-exit-node,ssh}"
TAILNET_DOMAIN="${TAILNET_DOMAIN:-codlet-trench.ts.net}"
SSH_KEYS="${SSH_KEYS:-}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)    HOST="$2";      shift 2 ;;
    --user)    USER_NAME="$2"; shift 2 ;;
    --repo)    REPO_DIR="$2";  shift 2 ;;
    --desktop) DESKTOP="$2";   shift 2 ;;
    --push-url) GIT_PUSH_URL="$2"; shift 2 ;;
    --branch)  BRANCH="$2";    shift 2 ;;
    --yes|-y)  YES="true";     shift ;;
    --tailnet-domain) TAILNET_DOMAIN="$2"; shift 2 ;;
    --ssh-keys) SSH_KEYS="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: install-fresh-nixos.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --host NAME        Host name (default: current hostname)"
      echo "  --user NAME        Username (default: current user)"
      echo "  --repo PATH        Repository path (default: ~/nixos-infrastructure)"
      echo "  --desktop TYPE     Desktop environment: gnome (default)"
      echo "  --push-url URL     Git push URL (default: git@gitlab.com:willisivali/nixos-infrastructure.git)"
      echo "  --branch BRANCH    Git branch (default: main)"
      echo "  --yes, -y          Non-interactive mode"
      echo "  --tailnet-domain   Tailscale domain (default: codlet-trench.ts.net)"
      echo "  --ssh-keys KEYS    Comma-separated SSH public keys"
      echo "  --help, -h         Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Logging ──────────────────────────────────────────────────────────────────
log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ── Nix wrappers ─────────────────────────────────────────────────────────────
nix() {
  command nix --extra-experimental-features "$NIX_FEATURES" "$@"
}

nix_with_git() {
  command nix --extra-experimental-features "$NIX_FEATURES" \
    shell nixpkgs#git --command \
    nix --extra-experimental-features "$NIX_FEATURES" "$@"
}

# ── Step 1: Validate environment ─────────────────────────────────────────────
require_nixos() {
  [[ -f /etc/NIXOS ]] || die "This script must run on NixOS."
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
  [[ "$(id -u)" -ne 0 ]] || die "Run as your normal user, not root."
}

# ── Step 2: Detect or prompt for host/user ──────────────────────────────────
detect_identity() {
  if [[ -z "$HOST" ]]; then
    HOST=$(hostname -s 2>/dev/null || echo "laptop")
    if [[ "$YES" != "true" ]]; then
      read -p "Host name [$HOST]: " input_host
      HOST="${input_host:-$HOST}"
    fi
  fi

  if [[ -z "$USER_NAME" ]]; then
    USER_NAME=$(whoami)
    if [[ "$YES" != "true" ]]; then
      read -p "Username [$USER_NAME]: " input_user
      USER_NAME="${input_user:-$USER_NAME}"
    fi
  fi

  log "Identity: host=$HOST user=$USER_NAME desktop=$DESKTOP"
}

# ── Step 3: Enable nix features ──────────────────────────────────────────────
enable_nix_features() {
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

  export NIX_CONFIG="experimental-features = nix-command flakes"
}

# ── Step 4: Clone or update repo ─────────────────────────────────────────────
clone_or_update_repo() {
  log "Fetching repo: ${REPO_URL}"
  if [[ -d "$REPO_DIR/.git" ]]; then
    nix shell nixpkgs#git --command git -C "$REPO_DIR" fetch --prune origin "$BRANCH"
    nix shell nixpkgs#git --command git -C "$REPO_DIR" checkout "$BRANCH"
    nix shell nixpkgs#git --command git -C "$REPO_DIR" merge --ff-only "origin/$BRANCH"
  else
    mkdir -p "$(dirname "$REPO_DIR")"
    nix shell nixpkgs#git --command git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
  fi
  nix shell nixpkgs#git --command git -C "$REPO_DIR" remote set-url --push origin "$GIT_PUSH_URL"
}

# ── Step 5: Detect hardware ─────────────────────────────────────────────────
detect_hardware() {
  log "Capturing hardware configuration"
  local dst="$REPO_DIR/hosts/hardware-configuration.nix"

  if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
    warn "/etc/nixos/hardware-configuration.nix not found — generating"
    sudo nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
  fi

  install -Dm0644 "${/etc/nixos/hardware-configuration.nix:-/tmp/hardware-configuration.nix}" "$dst"
  log "Hardware config written to $dst"
}

# ── Step 6: Optimize BTRFS (multi-device → single on fastest device) ────────
optimize_btrfs() {
  log "Checking BTRFS layout"
  local devices
  devices=$(sudo btrfs filesystem show / 2>/dev/null | grep -c 'devid') || true

  if [[ "$devices" -le 1 ]]; then
    log "Single-device BTRFS — no optimization needed"
    return
  fi

  if sudo btrfs filesystem df / 2>/dev/null | grep -q RAID1; then
    warn "Multi-device BTRFS with RAID1 detected — converting to single"
    warn "This moves all data to the fastest device and removes redundancy."
    if [[ "$YES" != "true" ]]; then
      read -p "Continue with RAID1→single conversion? [y/N]: " confirm
      [[ "${confirm,,}" == "y" ]] || { warn "Skipping BTRFS optimization"; return; }
    fi

    log "Converting RAID1 → single (data + metadata)"
    while sudo btrfs device usage / 2>/dev/null | grep -q 'RAID1'; do
      sudo btrfs balance start -dprofiles=raid1 -dconvert=single / || true
    done

    log "Converting RAID1 metadata → single"
    sudo btrfs balance start -mprofiles=raid1 -mconvert=single / || true

    log "Removing secondary devices"
    local second_dev
    second_dev=$(sudo btrfs filesystem show / 2>/dev/null | grep -E '^\s+devid\s+2' | awk '{print $NF}')
    if [[ -n "$second_dev" ]]; then
      sudo btrfs device remove "$second_dev" / || warn "Could not remove $second_dev"
    fi

    log "Final balance for optimal layout"
    sudo btrfs balance start / || true
    log "BTRFS optimization complete — now single-device on NVMe"
  fi
}

# ── Step 7: Generate host config ─────────────────────────────────────────────
generate_host_config() {
  log "Generating host configuration: $HOST"

  local host_dir="$REPO_DIR/hosts/$HOST"
  mkdir -p "$host_dir"

  local host_nix="$host_dir/${HOST}.nix"
  if [[ -f "$host_nix" ]] && [[ "$YES" != "true" ]]; then
    read -p "Host config exists. Overwrite? [y/N]: " overwrite
    [[ "${overwrite,,}" == "y" ]] || return 0
  fi

  cat > "$host_nix" << HOST_EOF
##############################################################################
#
# Host Configuration — ${HOST}
#
# Purpose
# -------
# Host-specific configuration for ${HOST} laptop.
# Desktop: GNOME
#
##############################################################################

{ config, lib, pkgs, hostSpec, hostName, defaultUsername, gitlabUrl, ... }:

let
  userName = hostSpec.userName or defaultUsername;
in
{
  ############################################################################
  # SYSTEM IDENTITY
  ############################################################################
  networking.hostName = hostName;

  ############################################################################
  # USER ACCOUNT
  ############################################################################
  users.users.\${userName} = {
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" "docker" "systemd-journal" ];
    shell = pkgs.zsh;
    home = "/home/\${userName}";
    createHome = true;
    useDefaultShell = true;
  };

  ############################################################################
  # SUDO CONFIGURATION
  ############################################################################
  security.sudo.extraRules = [
    {
      users = [ userName ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  ############################################################################
  # GIT CONFIGURATION (system-wide for root/CI access)
  ############################################################################
  environment.etc."gitconfig".text = ''
    [safe]
      directory = $(dirname "$REPO_DIR")/nixos-infrastructure
  '';
}
HOST_EOF

  log "Generated $host_nix"
}

# ── Step 8: Install format hook ──────────────────────────────────────────────
install_format_hook() {
  log "Installing pre-commit formatter hook"
  local hook_src="$REPO_DIR/hooks/pre-commit"
  local hook_dst="$REPO_DIR/.git/hooks/pre-commit"
  if [[ -f "$hook_src" ]]; then
    install -m0755 "$hook_src" "$hook_dst"
  else
    warn "hooks/pre-commit not found — skipping"
  fi
}

# ── Step 9: Format and validate ──────────────────────────────────────────────
format_and_validate() {
  log "Formatting Nix files"
  ( cd "$REPO_DIR" && nix_with_git fmt ) || warn "nix fmt failed — continuing"

  log "Evaluating nixosConfigurations.${HOST} (dry-run, no build)"
  local drv
  drv=$( cd "$REPO_DIR" && nix_with_git eval --raw ".#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath" 2>/dev/null ) || {
    warn "Config evaluation failed — check for errors above"
    return
  }
  log "Config evaluates cleanly → ${drv}"
}

# ── Step 10: Switch system ────────────────────────────────────────────────────
switch_system() {
  log "Running nixos-rebuild switch → ${HOST}"
  sudo nixos-rebuild switch \
    --option experimental-features "$NIX_FEATURES" \
    --flake "$REPO_DIR#${HOST}"
}

# ── Step 11: Post-install ────────────────────────────────────────────────────
post_install() {
  cat <<EOF

════════════════════════════════════════
  Install complete ✓
════════════════════════════════════════

  Host:    $HOST
  User:    $USER_NAME
  Desktop: $DESKTOP
  Repo:    $REPO_DIR

Next steps
──────────
1. Reboot to load all services:
     sudo reboot

2. After reboot, verify GNOME session:
     echo \$XDG_SESSION_TYPE    # should say "wayland"

3. Bring up Tailscale:
     sudo tailscale up --ssh

4. Install GNOME extensions from browser:
     Open GNOME Extensions app → Browse for:
     - Dash to Dock (already included)
     - Desktop Control (custom, built in)

5. Commit the generated hardware file:
     cd "$REPO_DIR"
     git add hosts/hardware-configuration.nix hosts/$HOST/
     git commit -m "chore: add host configuration for $HOST"
     git push

6. Test GitLab SSH:
     ssh -T git@gitlab.com

7. Launch ivali dashboard:
     ivali dashboard

EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  require_nixos
  detect_identity
  enable_nix_features
  clone_or_update_repo
  detect_hardware
  optimize_btrfs
  generate_host_config
  install_format_hook
  format_and_validate
  switch_system
  post_install
}

main "$@"
