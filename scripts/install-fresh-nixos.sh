#!/run/current-system/sw/bin/bash
# install-fresh-nixos.sh v4 — GNOME NixOS bootstrap
#
# Bootstrap a fresh NixOS machine with GNOME from the infrastructure flake.
# Designed to run on a freshly installed NixOS with the GNOME desktop option.
# Clones the repo, detects hardware, registers the host, and deploys.
#
# Usage:
#   nix --extra-experimental-features "nix-command flakes" \
#     shell nixpkgs#curl --command bash -c \
#     'curl -fsSL https://gitlab.com/willisivali/nixos-infrastructure/-/raw/main/scripts/install-fresh-nixos.sh | bash'
#
# Flags:
#   --host NAME        Host name (default: current hostname)
#   --user NAME        Username (default: current user)
#   --desktop gnome    Desktop environment (default: gnome)
#   --push-url URL     Git push URL (default: git@gitlab.com:willisivali/...)
#   --branch BRANCH    Git branch (default: main)
#   --yes, -y          Non-interactive mode
#   --tailnet-domain   Tailscale domain (default: codlet-trench.ts.net)
#   --ssh-keys KEYS    Comma-separated SSH public keys
#   --help, -h         Show this help
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
REPO_URL="${REPO_URL:-https://gitlab.com/willisivali/nixos-infrastructure.git}"
GIT_PUSH_URL="${GIT_PUSH_URL:-git@gitlab.com:willisivali/nixos-infrastructure.git}"
REPO_DIR="${REPO_DIR:-$HOME/nixos-infrastructure}"
BRANCH="${BRANCH:-main}"
NIX_FEATURES="nix-command flakes"

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
      echo "  --desktop TYPE     Desktop: gnome (default)"
      echo "  --push-url URL     Git push URL"
      echo "  --branch BRANCH    Git branch (default: main)"
      echo "  --yes, -y          Non-interactive mode"
      echo "  --tailnet-domain   Tailscale domain"
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
  log "Enabling nix-command + flakes"
  local conf_dir="$HOME/.config/nix"
  local conf="$conf_dir/nix.conf"
  mkdir -p "$conf_dir"

  if [[ ! -f "$conf" ]]; then
    printf 'experimental-features = nix-command flakes\n' > "$conf"
  elif ! grep -Eq '(^|[[:space:]])experimental-features[[:space:]]*=.*flakes' "$conf"; then
    printf '\nexperimental-features = nix-command flakes\n' >> "$conf"
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
  local hw_src="/etc/nixos/hardware-configuration.nix"

  if [[ ! -f "$hw_src" ]]; then
    warn "$hw_src not found — generating"
    hw_src=$(sudo nixos-generate-config --show-hardware-config 2>/dev/null) || {
      die "Failed to generate hardware configuration"
    }
    printf '%s\n' "$hw_src" > /tmp/hardware-configuration.nix
    hw_src=/tmp/hardware-configuration.nix
  fi

  install -Dm0644 "$hw_src" "$dst"
  log "Hardware config written to $dst"
}

# ── Step 6: Register host in hosts/hosts.nix ────────────────────────────────
register_host() {
  log "Registering host '$HOST' in hosts/hosts.nix"

  local registry="$REPO_DIR/hosts/hosts.nix"
  local entry

  # Build feature flags
  local f_secrets="true" f_runner="true" f_bot="true"
  local f_tailscale="true" f_exitnode="true" f_ssh="true"

  case ",${FEATURES}," in
    *,no-secrets,*)             f_secrets="false" ;;
    *,no-secrets,*)             f_secrets="false" ;;
    *,no-gitlab-runner,*)       f_runner="false" ;;
    *,no-bot,*)                 f_bot="false" ;;
    *,no-tailscale,*)           f_tailscale="false" ;;
    *,no-tailscale-exit-node,*) f_exitnode="false" ;;
    *,no-ssh,*)                 f_ssh="false" ;;
  esac

  # Parse optional SSH keys
  local keys_block=""
  if [[ -n "$SSH_KEYS" ]]; then
    IFS=',' read -ra keys <<< "$SSH_KEYS"
    for key in "${keys[@]}"; do
      keys_block+="      \"${key}\";\n"
    done
    keys_block="\n${keys_block}    "
  fi

  local host_entry
  host_entry=$(cat <<ENTRY_EOF

  ${HOST} = {
    hostName = "${HOST}";
    userName = "${USER_NAME}";
    repoPath = "${REPO_DIR}";
    tags = [ "tag:personal" ];
    tailnetDomain = "${TAILNET_DOMAIN}";
    gitlabRunnerTags = [ "nixos" "${HOST}" "self-hosted" ];
    sshAuthorizedKeys = [${keys_block}];
    sopsKeyPath = "/home/${USER_NAME}/.config/sops/age/keys.txt";
    features = {
      secrets = ${f_secrets};
      gitlabRunner = ${f_runner};
      bot = ${f_bot};
      tailscale = ${f_tailscale};
      tailscaleExitNode = ${f_exitnode};
      ssh = ${f_ssh};
    };
    config = {};
  };
ENTRY_EOF
)

  # Check if host already registered
  if grep -Eq "^\s+${HOST}\s*=" "$registry"; then
    log "Host '$HOST' already registered — updating registry entry"
    # Remove existing entry (from the line with hostname to its closing };)
    if [[ "$YES" == "true" ]]; then
      # Non-interactive: silently keep existing entry
      return 0
    fi
    read -p "Host '$HOST' already in registry. Overwrite? [y/N]: " overwrite
    [[ "${overwrite,,}" == "y" ]] || return 0
    # Remove old entry using awk (from match line to closing };)
    local tmp
    tmp=$(mktemp)
    awk -v host="${HOST}" '
      $0 ~ "^[[:space:]]*" host "[[:space:]]*=" { skip=1 }
      skip && /^[[:space:]]*};/ { skip=0; next }
      !skip { print }
    ' "$registry" > "$tmp"
    mv "$tmp" "$registry"
  fi

  # Insert new entry before the closing }
  local tmp
  tmp=$(mktemp)
  head -n -1 "$registry" > "$tmp"
  echo "$host_entry" >> "$tmp"
  echo "}" >> "$tmp"
  mv "$tmp" "$registry"

  log "Host '$HOST' registered in hosts/hosts.nix"
}

# ── Step 7: Optimize BTRFS (single NVMe) ────────────────────────────────────
optimize_btrfs() {
  log "Optimizing BTRFS filesystem"
  local devices
  devices=$(sudo btrfs filesystem show / 2>/dev/null | grep -c 'devid') || true

  if [[ "$devices" -gt 1 ]]; then
    warn "Multi-device BTRFS detected — skipping optimization"
    warn "This script assumes a single NVMe. Manually convert to single-device first."
    return
  fi

  log "Running BTRFS balance for optimal layout"
  sudo btrfs balance start / || true

  if command -v fstrim >/dev/null 2>&1; then
    log "Running fstrim to reclaim free space"
    sudo fstrim -va || true
  fi

  log "BTRFS optimization complete"
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

  log "Running flake check (no build)"
  ( cd "$REPO_DIR" && nix flake check --no-build ) || warn "flake check found issues — continuing"

  log "Evaluating nixosConfigurations.${HOST} (dry-run)"
  local drv
  drv=$( cd "$REPO_DIR" && nix_with_git eval --raw ".#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath" 2>/dev/null ) || {
    warn "Config evaluation failed — check for errors above"
    return
  }
  log "Config evaluates cleanly → ${drv}"
}

# ── Step 10: Switch system ───────────────────────────────────────────────────
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

4. Verify pre-installed GNOME Shell extensions:
     gnome-extensions list
   Expected: appindicatorsupport@rgcjonas.gmail.com,
             dash-to-dock@micxgx.gmail.com,
             blur-my-shell@aunetx,
             user-theme@gnome-shell-extensions.gcampax.github.com,
             caffeine@patapon.info,
             clipboard-indicator@tudmotu.com,
             Vitals@CoreCoding.com,
             sound-output-device-chooser@kgshank.net

5. Set up SOPS age key:
     mkdir -p ~/.config/sops/age
     # Copy your age key to ~/.config/sops/age/keys.txt

6. Commit and push generated files:
     cd "$REPO_DIR"
     git add hosts/hardware-configuration.nix hosts/hosts.nix
     git commit -m "chore: add host configuration for $HOST"
     git push all main

7. Test GitLab SSH:
     ssh -T git@gitlab.com

8. Verify the Telegram bot:
     systemctl status ivali-bot

EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  require_nixos
  detect_identity
  enable_nix_features
  clone_or_update_repo
  detect_hardware
  register_host
  optimize_btrfs
  install_format_hook
  format_and_validate
  switch_system
  post_install
}

main "$@"
