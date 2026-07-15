#!/run/current-system/sw/bin/bash
# install-fresh-nixos.sh v6 — GNOME NixOS bootstrap
#
# Bootstrap a fresh NixOS machine with GNOME from the infrastructure flake.
# Designed to run on a freshly installed NixOS with the GNOME desktop option.
# Clones the repo, detects hardware, registers the host, sets up secrets,
# generates SSH keys, and deploys.
#
# Usage:
#   nix --extra-experimental-features "nix-command flakes" \
#     shell nixpkgs#curl --command bash -c \
#     'curl -fsSL https://gitlab.com/willisivali/nixos-infrastructure/-/raw/main/scripts/install-fresh-nixos.sh | bash'
#
# Flags:
#   --host NAME          Host name (default: current hostname)
#   --user NAME          Username (default: current user)
#   --desktop gnome      Desktop environment (default: gnome)
#   --push-url URL       Git push URL
#   --branch BRANCH      Git branch (default: main)
#   --age-key-file PATH  Path to existing age key file (default: extract from sops-setup.sh)
#   --ssh-email EMAIL    Email for SSH key comment (default: itsivali@outlook.com)
#   --yes, -y            Non-interactive mode
#   --tailnet-domain     Tailscale domain (default: codlet-trench.ts.net)
#   --ssh-keys KEYS      Comma-separated SSH public keys
#   --no-ssh-keys        Skip SSH key generation
#   --help, -h           Show this help
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
AGE_KEY_FILE="${AGE_KEY_FILE:-}"
SSH_EMAIL="${SSH_EMAIL:-itsivali@outlook.com}"
NO_SSH_KEYS="${NO_SSH_KEYS:-false}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)            HOST="$2";      shift 2 ;;
    --user)            USER_NAME="$2"; shift 2 ;;
    --repo)            REPO_DIR="$2";  shift 2 ;;
    --desktop)         DESKTOP="$2";   shift 2 ;;
    --push-url)        GIT_PUSH_URL="$2"; shift 2 ;;
    --branch)          BRANCH="$2";    shift 2 ;;
    --age-key-file)    AGE_KEY_FILE="$2"; shift 2 ;;
    --ssh-email)       SSH_EMAIL="$2"; shift 2 ;;
    --yes|-y)          YES="true";     shift ;;
    --tailnet-domain)  TAILNET_DOMAIN="$2"; shift 2 ;;
    --ssh-keys)        SSH_KEYS="$2";  shift 2 ;;
    --no-ssh-keys)     NO_SSH_KEYS="true"; shift ;;
    --help|-h)
      echo "Usage: install-fresh-nixos.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --host NAME          Host name (default: current hostname)"
      echo "  --user NAME          Username (default: current user)"
      echo "  --desktop TYPE       Desktop: gnome (default)"
      echo "  --push-url URL       Git push URL"
      echo "  --branch BRANCH      Git branch (default: main)"
      echo "  --age-key-file PATH  Path to existing age key file"
      echo "  --ssh-email EMAIL    Email for SSH key comment"
      echo "  --yes, -y            Non-interactive mode"
      echo "  --tailnet-domain     Tailscale domain"
      echo "  --ssh-keys KEYS      Comma-separated SSH public keys"
      echo "  --no-ssh-keys        Skip SSH key generation"
      echo "  --help, -h           Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Visual style ─────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m';  C_BOLD=$'\033[1m';   C_DIM=$'\033[2m'
  C_BLUE=$'\033[1;34m'; C_CYAN=$'\033[1;36m'; C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_MAGENTA=$'\033[1;35m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_BLUE=''; C_CYAN=''
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_MAGENTA=''
fi

TOTAL_STEPS=15
STEP_NUM=0

banner() {
  printf '%s\n' "${C_CYAN}"
  cat <<'BANNER'
╔══════════════════════════════════════════════════════════╗
║        NixOS + GNOME  ·  Infrastructure Bootstrap          ║
╚══════════════════════════════════════════════════════════╝
BANNER
  printf '%s\n' "${C_RESET}"
}

# ── Logging ──────────────────────────────────────────────────────────────────
section() {
  STEP_NUM=$((STEP_NUM + 1))
  printf '\n%s┌─ [%02d/%02d] %s%s\n' "${C_CYAN}${C_BOLD}" "$STEP_NUM" "$TOTAL_STEPS" "$*" "${C_RESET}"
}
log()  { printf '%s│%s  %s✓%s %s\n' "${C_CYAN}" "${C_RESET}" "${C_GREEN}" "${C_RESET}" "$*"; }
note() { printf '%s│%s  %s· %s%s\n' "${C_CYAN}" "${C_RESET}" "${C_DIM}" "$*" "${C_RESET}"; }
warn() { printf '%s│%s  %s⚠ WARN%s  %s\n' "${C_CYAN}" "${C_RESET}" "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
die()  { printf '%s│%s  %s✗ ERROR%s %s\n\n' "${C_CYAN}" "${C_RESET}" "${C_RED}" "${C_RESET}" "$*" >&2; exit 1; }

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
  section "Validating environment"
  [[ -f /etc/NIXOS ]] || die "This script must run on NixOS."
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
  [[ "$(id -u)" -ne 0 ]] || die "Run as your normal user, not root."
  log "Running on NixOS as a regular user with sudo access"
}

# ── Step 2: Detect or prompt for host/user ──────────────────────────────────
detect_identity() {
  section "Identifying host"
  if [[ -z "$HOST" ]]; then
    HOST=$(hostname -s 2>/dev/null || echo "laptop")
    if [[ "$YES" != "true" ]]; then
      read -p "  Host name [$HOST]: " input_host
      HOST="${input_host:-$HOST}"
    fi
  fi

  if [[ -z "$USER_NAME" ]]; then
    USER_NAME=$(whoami)
    if [[ "$YES" != "true" ]]; then
      read -p "  Username [$USER_NAME]: " input_user
      USER_NAME="${input_user:-$USER_NAME}"
    fi
  fi

  log "host=${C_BOLD}${HOST}${C_RESET}  user=${C_BOLD}${USER_NAME}${C_RESET}  desktop=${C_BOLD}${DESKTOP}${C_RESET}"
}

# ── Step 3: Enable nix features ──────────────────────────────────────────────
enable_nix_features() {
  section "Enabling nix-command + flakes"
  local conf_dir="$HOME/.config/nix"
  local conf="$conf_dir/nix.conf"
  mkdir -p "$conf_dir"

  if [[ ! -f "$conf" ]]; then
    printf 'experimental-features = nix-command flakes\n' > "$conf"
  elif ! grep -Eq '(^|[[:space:]])experimental-features[[:space:]]*=.*flakes' "$conf"; then
    printf '\nexperimental-features = nix-command flakes\n' >> "$conf"
  fi

  export NIX_CONFIG="experimental-features = nix-command flakes"
  log "Experimental features active for this session and future ones"
}

# ── Step 4: Clone or update repo ─────────────────────────────────────────────
clone_or_update_repo() {
  section "Fetching infrastructure repo"
  note "$REPO_URL"
  if [[ -d "$REPO_DIR/.git" ]]; then
    nix shell nixpkgs#git --command git -C "$REPO_DIR" fetch --prune origin "$BRANCH"
    nix shell nixpkgs#git --command git -C "$REPO_DIR" checkout "$BRANCH"
    nix shell nixpkgs#git --command git -C "$REPO_DIR" merge --ff-only "origin/$BRANCH"
  else
    mkdir -p "$(dirname "$REPO_DIR")"
    nix shell nixpkgs#git --command git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
  fi
  nix shell nixpkgs#git --command git -C "$REPO_DIR" remote set-url --push origin "$GIT_PUSH_URL"
  log "Repo ready at $REPO_DIR (branch: $BRANCH)"
}

# ── Step 5: Detect hardware ─────────────────────────────────────────────────
detect_hardware() {
  section "Capturing hardware configuration"
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

# ── Step 6: Install SOPS age key ─────────────────────────────────────────────
setup_age_key() {
  section "Installing SOPS age key"
  local key_dir="$HOME/.config/sops/age"
  local key_file="$key_dir/keys.txt"

  # Priority: --age-key-file > $AGE_KEY env > sops-setup.sh > prompt
  if [[ -n "$AGE_KEY_FILE" ]]; then
    note "Source: --age-key-file ${AGE_KEY_FILE}"
    [[ -f "$AGE_KEY_FILE" ]] || die "Age key file not found: $AGE_KEY_FILE"
    mkdir -p "$key_dir"
    cp "$AGE_KEY_FILE" "$key_file"
  elif [[ -n "${AGE_KEY:-}" ]]; then
    note "Source: AGE_KEY env var"
    mkdir -p "$key_dir"
    printf '%s\n' "$AGE_KEY" > "$key_file"
  elif [[ -f "$REPO_DIR/scripts/sops-setup.sh" ]]; then
    note "Source: scripts/sops-setup.sh"
    bash "$REPO_DIR/scripts/sops-setup.sh"
    # sops-setup.sh has hardcoded /home/ivali — symlink if user differs
    if [[ "$USER_NAME" != "ivali" ]]; then
      mkdir -p "$key_dir"
      ln -sf "/home/ivali/.config/sops/age/keys.txt" "$key_file"
    fi
    log "Age key installed via sops-setup.sh"
    return
  elif [[ "$YES" == "true" ]]; then
    warn "Non-interactive mode and no age key source — skipping"
    warn "Provide --age-key-file or AGE_KEY env var"
    return
  else
    note "No age key source found — paste your existing age key"
    note "Get it from: cat ~/.config/sops/age/keys.txt (on your old system)"
    mkdir -p "$key_dir"
    echo "  Paste the entire AGE-SECRET-KEY-... line, then press Ctrl+D:"
    cat > "$key_file" || {
      warn "No key entered — skipping age key setup"
      rm -f "$key_file"
      return
    }
    if [[ ! -s "$key_file" ]]; then
      warn "Empty key — skipping"
      rm -f "$key_file"
      return
    fi
  fi

  chmod 700 "$key_dir"
  chmod 600 "$key_file"

  # Verify it looks like an age key
  if head -1 "$key_file" | grep -q 'AGE-SECRET-KEY-'; then
    log "Age key installed at $key_file"
    local pub
    pub=$(age-keygen -y "$key_file" 2>/dev/null || true)
    [[ -n "$pub" ]] && log "Public key: ${pub}"
  else
    warn "File does not look like a valid age key — check content"
  fi
}

# ── Step 7: Register host in hosts/hosts.nix ────────────────────────────────
register_host() {
  section "Registering host in hosts/hosts.nix"

  local registry="$REPO_DIR/hosts/hosts.nix"

  # Build feature flags
  local f_secrets="true" f_runner="true" f_bot="true"
  local f_tailscale="true" f_exitnode="true" f_ssh="true"

  case ",${FEATURES}," in
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

  # If the host is already registered, pull out its existing `config = { ... };`
  # block *before* touching the registry, so a re-run never silently discards
  # hand-written NixOS config overrides (this is how a real customization
  # ended up orphaned in the file previously).
  local config_block="    config = {};"
  if grep -Eq "^\s+${HOST}\s*=" "$registry"; then
    log "Host '$HOST' already registered — updating registry entry"
    if [[ "$YES" == "true" ]]; then
      return 0
    fi
    read -p "  Host '$HOST' already in registry. Overwrite? [y/N]: " overwrite
    [[ "${overwrite,,}" == "y" ]] || return 0

    local existing_config
    existing_config=$(awk -v host="${HOST}" '
      BEGIN { in_host = 0; hdepth = 0; in_cfg = 0; cdepth = 0 }
      {
        line = $0
        if (in_host == 0 && line ~ ("^[[:space:]]*" host "[[:space:]]*=[[:space:]]*\\{")) {
          in_host = 1; hdepth = 0
        }
        if (in_host == 1) {
          if (in_cfg == 0 && line ~ /^[[:space:]]*config[[:space:]]*=[[:space:]]*\{/) {
            in_cfg = 1; cdepth = 0
          }
          if (in_cfg == 1) {
            print line
            co = gsub(/\{/, "{", line); cc = gsub(/\}/, "}", line)
            cdepth += co - cc
            if (cdepth <= 0) in_cfg = 0
          }
          ho = gsub(/\{/, "{", line); hc = gsub(/\}/, "}", line)
          hdepth += ho - hc
          if (hdepth <= 0) in_host = 0
        }
      }
    ' "$registry")

    # Only trust it if it is more than a trivial empty override
    if [[ -n "$existing_config" && "$(tr -d '[:space:]' <<< "$existing_config")" != "config={};" ]]; then
      config_block="$existing_config"
      note "Preserving existing config override for '${HOST}'"
    fi

    # Remove the existing entry by tracking brace depth, not just the
    # first "};" line — nested blocks (e.g. `features = { ... };`) close
    # *before* the entry itself does, so a naive first-match strips too
    # little and leaves orphaned lines behind.
    local tmp
    tmp=$(mktemp)
    awk -v host="${HOST}" '
      BEGIN { skip = 0; depth = 0 }
      {
        line = $0
        if (skip == 0 && line ~ ("^[[:space:]]*" host "[[:space:]]*=[[:space:]]*\\{")) {
          skip = 1
          depth = 0
        }
        if (skip == 1) {
          o = gsub(/\{/, "{", line)
          c = gsub(/\}/, "}", line)
          depth += o - c
          if (depth <= 0) skip = 0
          next
        }
        print
      }
    ' "$registry" > "$tmp"
    mv "$tmp" "$registry"
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
${config_block}
  };
ENTRY_EOF
)

  local tmp
  tmp=$(mktemp)
  head -n -1 "$registry" > "$tmp"
  echo "$host_entry" >> "$tmp"
  echo "}" >> "$tmp"
  mv "$tmp" "$registry"

  log "Host '$HOST' registered in hosts/hosts.nix"
}

# ── Step 8: Validate hosts.nix syntax ───────────────────────────────────────
validate_registry_syntax() {
  section "Checking hosts.nix syntax"
  local registry="$REPO_DIR/hosts/hosts.nix"

  if ! command -v nix-instantiate >/dev/null 2>&1; then
    warn "nix-instantiate not found — skipping syntax check"
    return
  fi

  local err
  if ! err=$(nix-instantiate --parse "$registry" 2>&1 >/dev/null); then
    die "hosts.nix has a syntax error — stopping before any deploy step:
${err}

This usually means a stale registry entry wasn't fully cleaned up.
Open $registry and check the entry for '${HOST}' for a stray closing brace."
  fi

  log "hosts.nix parses cleanly"
}

# ── Step 9: Optimize BTRFS (single NVMe) ────────────────────────────────────
optimize_btrfs() {
  section "Optimizing BTRFS filesystem"
  local devices
  devices=$(sudo btrfs filesystem show / 2>/dev/null | grep -c 'devid') || true

  if [[ "$devices" -gt 1 ]]; then
    warn "Multi-device BTRFS detected — skipping optimization"
    warn "This script assumes a single NVMe. Manually convert to single-device first."
    return
  fi

  note "Running BTRFS balance for optimal layout"
  sudo btrfs balance start / || true

  if command -v fstrim >/dev/null 2>&1; then
    note "Running fstrim to reclaim free space"
    sudo fstrim -va || true
  fi

  log "BTRFS optimization complete"
}

# ── Step 10: Install format hook ─────────────────────────────────────────────
install_format_hook() {
  section "Installing pre-commit formatter hook"
  local hook_src="$REPO_DIR/hooks/pre-commit"
  local hook_dst="$REPO_DIR/.git/hooks/pre-commit"
  if [[ -f "$hook_src" ]]; then
    install -m0755 "$hook_src" "$hook_dst"
    log "Pre-commit hook installed (applies on future commits only)"
  else
    warn "hooks/pre-commit not found — skipping"
  fi
}

# ── Step 11: Validate flake ──────────────────────────────────────────────────
validate_flake() {
  section "Validating flake"
  note "Running flake check (no build)"
  ( cd "$REPO_DIR" && nix flake check --no-build ) || warn "flake check found issues — continuing"

  note "Evaluating nixosConfigurations.${HOST} (dry-run)"
  local drv
  drv=$( cd "$REPO_DIR" && nix_with_git eval --raw ".#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath" 2>/dev/null ) || {
    warn "Config evaluation failed — check for errors above"
    return
  }
  log "Config evaluates cleanly → ${drv}"
}

# ── Step 12: Switch system ───────────────────────────────────────────────────
switch_system() {
  section "Running nixos-rebuild switch"
  note "Target: ${HOST}"
  sudo nixos-rebuild switch \
    --option experimental-features "$NIX_FEATURES" \
    --flake "$REPO_DIR#${HOST}"
  log "System switched to the new configuration"
}

# ── Step 13: Validate SOPS secrets ──────────────────────────────────────────
validate_sops() {
  section "Validating SOPS secrets"

  if [[ ! -d /run/secrets ]]; then
    warn "/run/secrets/ does not exist — SOPS may not be configured"
    return
  fi

  local secrets
  secrets=$(ls -1 /run/secrets/ 2>/dev/null | wc -l) || secrets=0

  if [[ "$secrets" -eq 0 ]]; then
    warn "/run/secrets/ is empty — age key may be wrong or sops-nix config is broken"
    warn "Check: systemctl status sops-nix"
    warn "Check: cat ~/.config/sops/age/keys.txt (must be valid)"
  else
    log "SOPS secrets mounted at /run/secrets/ (${secrets} files)"
  fi
}

# ── Step 14: Generate SSH keys ───────────────────────────────────────────────
generate_ssh_keys() {
  section "Setting up SSH keys"
  if [[ "$NO_SSH_KEYS" == "true" ]]; then
    log "Skipping SSH key generation (--no-ssh-keys)"
    return
  fi

  local key="$HOME/.ssh/id_ed25519"

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [[ -f "$key" ]]; then
    log "SSH key already exists: ${key}"
  else
    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$key" -N "" || {
      warn "SSH key generation failed — check: ssh-keygen available?"
      return
    }
    log "SSH key generated: ${key}"
  fi

  # Start ssh-agent if necessary
  if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
  fi
  ssh-add "$key" >/dev/null 2>&1 || true

  printf '\n%s│%s  %s┌────────────────────────────────────────┐%s\n' "${C_CYAN}" "${C_RESET}" "${C_MAGENTA}" "${C_RESET}"
  printf '%s│%s  %s│  SSH Public Key                          │%s\n' "${C_CYAN}" "${C_RESET}" "${C_MAGENTA}" "${C_RESET}"
  printf '%s│%s  %s└────────────────────────────────────────┘%s\n' "${C_CYAN}" "${C_RESET}" "${C_MAGENTA}" "${C_RESET}"
  printf '%s│%s  %s\n' "${C_CYAN}" "${C_RESET}" "$(cat "${key}.pub")"
  printf '%s│%s\n' "${C_CYAN}" "${C_RESET}"
  note "Add this key to:"
  note "  GitHub: https://github.com/settings/ssh/new"
  note "  GitLab: https://gitlab.com/-/user_settings/ssh_keys"
  log "SSH key setup complete"
}

# ── Step 15: Post-install ────────────────────────────────────────────────────
post_install() {
  printf '\n%s╔══════════════════════════════════════════════════════════╗%s\n' "${C_GREEN}${C_BOLD}" "${C_RESET}"
  printf '%s║%s  ✓ Install complete                                       %s║%s\n' "${C_GREEN}${C_BOLD}" "${C_RESET}" "${C_GREEN}${C_BOLD}" "${C_RESET}"
  printf '%s╚══════════════════════════════════════════════════════════╝%s\n\n' "${C_GREEN}${C_BOLD}" "${C_RESET}"

  printf '  %sHost%s     %s\n'    "${C_DIM}" "${C_RESET}" "$HOST"
  printf '  %sUser%s     %s\n'    "${C_DIM}" "${C_RESET}" "$USER_NAME"
  printf '  %sDesktop%s  %s\n'    "${C_DIM}" "${C_RESET}" "$DESKTOP"
  printf '  %sRepo%s     %s\n\n'  "${C_DIM}" "${C_RESET}" "$REPO_DIR"

  printf '%sNext steps%s\n' "${C_BOLD}" "${C_RESET}"
  cat <<EOF
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

  5. Add your SSH public key to GitHub and GitLab:
       GitHub: https://github.com/settings/ssh/new
       GitLab: https://gitlab.com/-/user_settings/ssh_keys

  6. Test SSH connections:
       ssh -T git@github.com
       ssh -T git@gitlab.com

  7. Verify the Telegram bot:
       systemctl status ivali-bot

  8. Commit and push generated files:
       cd "$REPO_DIR"
       git add hosts/hardware-configuration.nix hosts/hosts.nix
       git commit -m "chore: add host configuration for $HOST"
       git push all main

EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  banner
  require_nixos
  detect_identity
  enable_nix_features
  clone_or_update_repo
  detect_hardware
  setup_age_key
  register_host
  validate_registry_syntax
  optimize_btrfs
  install_format_hook
  validate_flake
  switch_system
  validate_sops
  generate_ssh_keys
  post_install
}

main "$@"
