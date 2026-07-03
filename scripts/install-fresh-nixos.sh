#!/run/current-system/sw/bin/bash
# install-fresh-nixos.sh v2 — Universal laptop bootstrap
#
# Bootstrap a fresh NixOS machine from the willisivali/nixos-infrastructure flake.
# Works on any laptop with GNOME desktop environment.
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
FEATURES="${FEATURES:-secrets,gitlab-runner,bot,tailscale,tailscale-exit-node,ssh}"
TAILNET_DOMAIN="${TAILNET_DOMAIN:-codlet-trench.ts.net}"
SSH_KEYS="${SSH_KEYS:-}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)    HOST="$2";      shift 2 ;;
    --user)    USER_NAME="$2"; shift 2 ;;
    --repo)    REPO_DIR="$2";  shift 2 ;;
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

  log "Identity: host=$HOST user=$USER_NAME"
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

# ── Step 6: Generate host config ─────────────────────────────────────────────
generate_host_config() {
  log "Generating host configuration: $HOST"

  # Build host spec file
  local host_dir="$REPO_DIR/hosts/$HOST"
  mkdir -p "$host_dir"

  local host_nix="$host_dir/${HOST}.nix"
  if [[ -f "$host_nix" ]] && [[ "$YES" != "true" ]]; then
    read -p "Host config exists. Overwrite? [y/N]: " overwrite
    [[ "${overwrite,,}" == "y" ]] || return 0
  fi

  # Generate host.nix from template
  cat > "$host_nix" << 'HOST_EOF'
##############################################################################
#
# Host Configuration — HOST_PLACEHOLDER
#
# Purpose
# -------
# Host-specific configuration for HOST_PLACEHOLDER laptop.
# Generated by: ivali bootstrap host HOST_PLACEHOLDER
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
  users.users.${userName} = {
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" "docker" "systemd-journal" "flatpak" ];
    shell = config.programs.zsh.package.path + "/bin/zsh";
    home = "/home/${userName}";
    createHome = true;
    useDefaultShell = true;
  };

  systemd.tmpfiles.rules = [
    "d /home/${userName} 0755 ${userName} ${userName} -"
  ];

  ############################################################################
  # SUDO CONFIGURATION
  ############################################################################
  security.sudo.extraRules = [
    # Primary user gets full sudo
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
      directory = HOME_PLACEHOLDER/nixos-infrastructure
  '';
}
HOST_EOF

  # Replace placeholders
  sed -i "s/HOST_PLACEHOLDER/$HOST/g" "$host_nix"
  sed -i "s|HOME_PLACEHOLDER|$(dirname "$REPO_DIR")|g" "$host_nix"

  log "Generated $host_nix"
}

# ── Step 7: Install format hook ──────────────────────────────────────────────
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

# ── Step 8: Format and validate ──────────────────────────────────────────────
format_and_validate() {
  log "Formatting Nix files"
  ( cd "$REPO_DIR" && nix_with_git fmt )

  log "Evaluating nixosConfigurations.${HOST} (dry-run, no build)"
  local drv
  drv=$( cd "$REPO_DIR" && nix_with_git eval --raw ".#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath" )
  log "Config evaluates cleanly → ${drv}"
}

# ── Step 9: Switch system ────────────────────────────────────────────────────
switch_system() {
  log "Running nixos-rebuild switch → ${HOST}"
  sudo nixos-rebuild switch \
    --option experimental-features "$NIX_FEATURES" \
    --flake "$REPO_DIR#${HOST}"
}

# ── Step 10: Post-install ────────────────────────────────────────────────────
post_install() {
  cat <<EOF

════════════════════════════════════════
  Install complete ✓
════════════════════════════════════════

  Host:   $HOST
  User:   $USER_NAME
  Repo:   $REPO_DIR

Next steps
──────────
1. Reboot to load all services:
     sudo reboot

2. After reboot, bring up Tailscale:
     sudo tailscale up --ssh

3. Commit the generated hardware file:
     cd "$REPO_DIR"
     git add hosts/hardware-configuration.nix
     git commit -m "chore: add hardware configuration for $HOST"
     git push

4. Test GitLab SSH:
     ssh -T git@gitlab.com

5. Access local services (after reboot):
     Grafana    http://localhost:3000   (admin / admin on first boot)
     Prometheus http://localhost:9090
     Loki       http://localhost:3100

6. Open config in your editor:
     ivali dashboard

Docs
────
  Grafana    https://grafana.com/docs/grafana/latest/getting-started/
  Prometheus https://prometheus.io/docs/tutorials/getting_started/
  Loki       https://grafana.com/docs/loki/latest/configuration/
  Alloy      https://grafana.com/docs/alloy/latest/
EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  require_nixos
  detect_identity
  enable_nix_features
  clone_or_update_repo
  detect_hardware
  generate_host_config
  install_format_hook
  format_and_validate
  switch_system
  post_install
}

main "$@"