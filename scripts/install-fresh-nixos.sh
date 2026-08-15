#!/usr/bin/env bash
# install-fresh-nixos.sh — NixOS + GNOME bootstrap
#
# Bootstrap a freshly installed NixOS machine with the desktop and
# infrastructure flake. Designed to run on a new NixOS system (as your normal
# user with sudo). The script:
#
#   1. Enables the nix-command/flakes experimental features
#   2. Installs git, age, and sops into your user profile (the repo's NixOS
#      config also ships them system-wide after the first switch)
#   3. Clones the infrastructure repo and detects hardware
#   4. Copies your SOPS age key from your old system and guarantees the
#      ~/.config/sops/age/keys.txt path exists
#   5. Registers the host in the flake, validates, and deploys
#   6. Generates SSH keys and reports next steps
#
# Usage:
#   The repo is private, so it cannot be fetched over plain HTTPS/raw on a
#   fresh system. Save this script to a USB stick, generate an SSH key, add
#   it to GitLab (https://gitlab.com/-/user_settings/ssh_keys), then run:
#
#     ssh-keygen -t ed25519 -C "itsivali@outlook.com" -f ~/.ssh/id_ed25519 -N ""
#     bash install-fresh-nixos.sh
#
#   The clone defaults to SSH (git@gitlab.com:...) which requires the key to
#   be registered with GitLab BEFORE this script runs (the repo clone happens
#   before SSH key generation).
#
# Flags:
#   --host NAME          Host name (default: current hostname)
#   --user NAME          Username (default: current user)
#   --desktop gnome     Desktop environment (default: gnome)
#   --repo-url URL       Git clone URL (default: git@gitlab.com:... over SSH)
#   --push-url URL       Git push URL
#   --branch BRANCH      Git branch (default: main)
#   --age-key-file PATH  Path to an existing age key file to copy
#   --ssh-email EMAIL    Email for SSH key comment (default: itsivali@outlook.com)
#   --yes, -y            Non-interactive mode
#   --tailnet-domain     Tailscale domain (default: codlet-trench.ts.net)
#   --ssh-keys KEYS      Comma-separated SSH public keys
#   --no-ssh-keys        Skip SSH key generation
#   --features LIST      Comma-separated features (default: secrets,bitwarden,gitlab-runner,bot,tailscale,tailscale-exit-node,ssh)
#   --help, -h           Show this help
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
# Private repo: clone over SSH (requires the key registered with GitLab first).
# Override with --repo-url if you need HTTPS (e.g. a deploy token).
REPO_URL="${REPO_URL:-git@gitlab.com:willisivali/nixos-infrastructure.git}"
GIT_PUSH_URL="${GIT_PUSH_URL:-git@gitlab.com:willisivali/nixos-infrastructure.git}"
REPO_DIR="${REPO_DIR:-$HOME/nixos-infrastructure}"
BRANCH="${BRANCH:-main}"
NIX_FEATURES="nix-command flakes"

HOST="${HOST:-}"
USER_NAME="${USER_NAME:-}"
YES="${YES:-false}"
DESKTOP="${DESKTOP:-gnome}"
FEATURES="${FEATURES:-secrets,bitwarden,gitlab-runner,bot,tailscale,tailscale-exit-node,ssh}"
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
    --repo-url)        REPO_URL="$2";  shift 2 ;;
    --desktop)         DESKTOP="$2";   shift 2 ;;
    --push-url)        GIT_PUSH_URL="$2"; shift 2 ;;
    --branch)          BRANCH="$2";    shift 2 ;;
    --age-key-file)    AGE_KEY_FILE="$2"; shift 2 ;;
    --ssh-email)       SSH_EMAIL="$2"; shift 2 ;;
    --yes|-y)          YES="true";     shift ;;
    --tailnet-domain)  TAILNET_DOMAIN="$2"; shift 2 ;;
    --ssh-keys)        SSH_KEYS="$2";  shift 2 ;;
    --no-ssh-keys)     NO_SSH_KEYS="true"; shift ;;
    --features)        FEATURES="$2";  shift 2 ;;
    --help|-h)
      echo "Usage: install-fresh-nixos.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --host NAME          Host name (default: current hostname)"
      echo "  --user NAME          Username (default: current user)"
      echo "  --desktop TYPE       Desktop: gnome (default)"
      echo "  --repo-url URL       Git clone URL (default: SSH git@gitlab.com:...)"
      echo "  --push-url URL       Git push URL"
      echo "  --branch BRANCH      Git branch (default: main)"
      echo "  --age-key-file PATH  Path to an existing age key file to copy"
      echo "  --ssh-email EMAIL    Email for SSH key comment"
      echo "  --yes, -y            Non-interactive mode"
      echo "  --tailnet-domain     Tailscale domain"
      echo "  --ssh-keys KEYS      Comma-separated SSH public keys"
      echo "  --no-ssh-keys        Skip SSH key generation"
      echo "  --features LIST      Comma-separated feature flags"
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
║        NixOS + GNOME · Infrastructure Bootstrap         ║
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

# ── Step 4: Install git, age, sops (bootstrap prerequisites) ────────────────
install_tools() {
  section "Installing bootstrap tools (git, age, sops)"
  note "This installs into your Nix user profile; the flake also ships them system-wide after the first switch."

  # Make the bootstrap profile available for the rest of this session.
  export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

  if command -v git >/dev/null 2>&1 && command -v age-keygen >/dev/null 2>&1 && command -v sops >/dev/null 2>&1; then
    log "git, age, and sops already available"
    return
  fi

  local missing=""
  for pkg in git age sops; do
    command -v "$pkg" >/dev/null 2>&1 || missing+=" nixpkgs#${pkg}"
  done
  missing="${missing## }"

  if [[ -n "$missing" ]]; then
    note "Installing: ${missing}"
    if ! nix profile install $missing; then
      warn "nix profile install failed — falling back to nix-env"
      local attrs=()
      for pkg in $missing; do
        attrs+=("-A" "nixpkgs.${pkg#nixpkgs#}")
      done
      nix-env -i "${attrs[@]}"
    fi
    log "Bootstrap tools installed into $HOME/.nix-profile"
  fi

  command -v git >/dev/null 2>&1 || die "git is required (install failed)"
  command -v age-keygen >/dev/null 2>&1 || warn "age-keygen not found — age key validation will be limited"
  command -v sops >/dev/null 2>&1 || warn "sops not found — secret re-encryption step will be skipped"
}

# ── Step 5: Clone or update repo ─────────────────────────────────────────────
clone_or_update_repo() {
  section "Fetching infrastructure repo"
  note "$REPO_URL"

  # Seamless first-time SSH clone: pre-accept gitlab.com's host key so the
  # non-interactive run does not hang on the "authenticity of host" prompt.
  if [[ "$REPO_URL" == git@* || "$REPO_URL" == ssh://* ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/known_hosts"
    chmod 600 "$HOME/.ssh/known_hosts"
    if ! ssh-keygen -F gitlab.com >/dev/null 2>&1; then
      ssh-keyscan -T 10 -t ed25519 gitlab.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
    fi
  fi

  if [[ -d "$REPO_DIR/.git" ]]; then
    git -C "$REPO_DIR" fetch --prune origin "$BRANCH"
    git -C "$REPO_DIR" checkout "$BRANCH"
    git -C "$REPO_DIR" merge --ff-only "origin/$BRANCH"
  else
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
  fi
  git -C "$REPO_DIR" remote set-url --push origin "$GIT_PUSH_URL"
  log "Repo ready at $REPO_DIR (branch: $BRANCH)"
}

# ── Step 6: Detect hardware ─────────────────────────────────────────────────
detect_hardware() {
  section "Capturing hardware configuration"
  local host_dir="$REPO_DIR/hosts/${HOST}"
  local dst="$host_dir/hardware-configuration.nix"
  local hw_src="/etc/nixos/hardware-configuration.nix"

  mkdir -p "$host_dir"

  if [[ ! -f "$hw_src" ]]; then
    warn "$hw_src not found — generating"
    local gen_out
    gen_out=$(sudo nixos-generate-config --show-hardware-config 2>/dev/null) || die "Failed to generate hardware configuration"
    printf '%s\n' "$gen_out" > /tmp/hardware-configuration.nix
    hw_src=/tmp/hardware-configuration.nix
  fi

  install -Dm0644 "$hw_src" "$dst"
  log "Hardware config written to $dst"
}

# ── Step 7: Install SOPS age key (copied from existing system) ──────────────
setup_age_key() {
  section "Installing SOPS age key"
  local key_dir="$HOME/.config/sops/age"
  local key_file="$key_dir/keys.txt"

  # Priority: --age-key-file > $AGE_KEY env > interactive paste. The age key
  # is the SAME key used on your existing system — do not generate a new one
  # or existing secrets cannot be decrypted.
  if [[ -n "$AGE_KEY_FILE" ]]; then
    note "Source: --age-key-file ${AGE_KEY_FILE}"
    [[ -f "$AGE_KEY_FILE" ]] || die "Age key file not found: $AGE_KEY_FILE"
    mkdir -p "$key_dir"
    cp "$AGE_KEY_FILE" "$key_file"
  elif [[ -n "${AGE_KEY:-}" ]]; then
    note "Source: AGE_KEY env var"
    mkdir -p "$key_dir"
    printf '%s\n' "$AGE_KEY" > "$key_file"
  elif [[ -f "$key_file" ]] && grep -q 'AGE-SECRET-KEY-' "$key_file"; then
    note "Age key already present at $key_file — leaving it untouched"
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
  if grep -q 'AGE-SECRET-KEY-' "$key_file"; then
    log "Age key installed at $key_file (path guaranteed for sops-nix)"
    register_sops_key
  else
    warn "File does not look like a valid age key — check content"
  fi
}

# Register the installed age key's public key in .sops.yaml so sops-nix can
# decrypt the repo secrets on this host. When the key differs from the primary
# (prague) key, warn that secrets must be re-encrypted from the old machine.
register_sops_key() {
  local key_file="$HOME/.config/sops/age/keys.txt"
  local sops_yaml="$REPO_DIR/.sops.yaml"
  [[ -f "$sops_yaml" ]] || { warn ".sops.yaml not found in repo — skipping key registration"; return; }

  command -v age-keygen >/dev/null 2>&1 || { warn "age-keygen missing — cannot derive public key"; return; }
  local pub anchor primary_pub
  pub=$(age-keygen -y "$key_file" 2>/dev/null) || { warn "Could not derive public key from age key"; return; }
  anchor="${HOST}"
  log "Age public key: ${pub}"

  # Primary key currently listed in .sops.yaml (captured before any change).
  primary_pub=$(grep -oE 'age1[0-9a-z]+' "$sops_yaml" | head -1 || true)

  if grep -q "$pub" "$sops_yaml" 2>/dev/null; then
    note "Public key already registered in .sops.yaml"
    if [[ -n "$primary_pub" && "$primary_pub" != "$pub" ]]; then
      warn "This host uses a different key than the primary (${primary_pub})."
    fi
    return
  fi

  note "Registering public key in .sops.yaml (anchor: ${anchor})"

  # Add the key to the top-level keys list.
  if ! grep -q "&${anchor} " "$sops_yaml" 2>/dev/null; then
    sed -i "0,/^keys:/s|^keys:|keys:\n  - \\&${anchor} ${pub}|" "$sops_yaml"
  fi

  # Reference the anchor from the first age key group in creation_rules.
  if ! grep -q "\\*${anchor}" "$sops_yaml" 2>/dev/null; then
    awk -v a="$anchor" '
      /^[ ]+- \*.*/ && !done { print; print "          - *" a; done=1; next }
      { print }
    ' "$sops_yaml" > "$sops_yaml.tmp" && mv "$sops_yaml.tmp" "$sops_yaml"
  fi

  # If this is a different key than the primary, the repo secrets are only
  # encrypted for the primary key — they must be re-encrypted from a machine
  # that holds the old key (after this one is added to .sops.yaml).
  if [[ -n "$primary_pub" && "$primary_pub" != "$pub" ]]; then
    warn "This host uses a DIFFERENT age key than the primary (${primary_pub})."
    warn "Re-encrypt the secrets from your old machine so both keys can decrypt:"
    warn "  sops -e -i secrets/*.yaml   (with both keys listed in .sops.yaml)"
  else
    log "Primary key matches — secrets will decrypt on this host"
  fi
}

# ── Step 8: Register host ────────────────────────────────────────────────────
register_host() {
  section "Creating host spec: hosts/${HOST}.nix"

  local host_spec="$REPO_DIR/hosts/${HOST}.nix"

  # Build feature flags
  local f_secrets="true" f_bitwarden="true" f_runner="true" f_bot="true"
  local f_tailscale="true" f_exitnode="true" f_ssh="true"

  case ",${FEATURES}," in
    *,no-secrets,*)             f_secrets="false" ;;
    *,no-bitwarden,*)           f_bitwarden="false" ;;
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
      keys_block+="    \"${key}\";"$'\n'
    done
  fi

  local sops_key_path="${HOME}/.config/sops/age/keys.txt"

  # If the host spec already exists, offer to preserve it
  if [[ -f "$host_spec" ]]; then
    log "Host spec '${host_spec}' already exists"
    if [[ "$YES" == "true" ]]; then
      return 0
    fi
    read -p "  Overwrite existing host spec? [y/N]: " overwrite
    [[ "${overwrite,,}" == "y" ]] || return 0
  fi

  mkdir -p "$(dirname "$host_spec")"

  cat > "$host_spec" <<EOF
##############################################################################
#
# $(echo "${HOST}" | sed 's/./\U&/') — Host Spec
#
# Purpose
# -------
# Host spec for ${HOST}. Auto-discovered by hosts/hosts.nix aggregator.
# Generated by: scripts/install-fresh-nixos.sh
#
##############################################################################

{ lib, ... }:

{
  hostName = "${HOST}";
  userName = "${USER_NAME}";
  repoPath = "${REPO_DIR}";
  tags = [ "tag:personal" ];
  tailnetDomain = "${TAILNET_DOMAIN}";
  gitlabRunnerTags = [ "nixos" "${HOST}" "self-hosted" ];
  sshAuthorizedKeys = [
${keys_block}  ];
  sopsKeyPath = "${sops_key_path}";
  features = {
    secrets = ${f_secrets};
    bitwarden = ${f_bitwarden};
    gitlabRunner = ${f_runner};
    bot = ${f_bot};
    tailscale = ${f_tailscale};
    tailscaleExitNode = ${f_exitnode};
    ssh = ${f_ssh};
  };
  config = {
    ivali.desktop.gnome.enable = true;
  };
}
EOF

  # Create a placeholder per-host secrets file (mirrors secrets/hosts/prague.yaml).
  local host_secrets="$REPO_DIR/secrets/hosts/${HOST}.yaml"
  if [[ ! -f "$host_secrets" ]]; then
    mkdir -p "$(dirname "$host_secrets")"
    cat > "$host_secrets" <<EOF
# SOPS secrets for ${HOST}
#
# Encrypt with: sops --encrypt --age <age-public-key> secrets/hosts/${HOST}.yaml
#
# Example structure:
# ssh_authorized_keys:
#   - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@device"
# tailscale_authkey: "tskey-auth-..."
# gitlab_runner_token: "glrt-..."
EOF
    log "Per-host secrets placeholder created: ${host_secrets}"
  fi

  log "Host spec created: ${host_spec}"
}

# ── Step 9: Validate host spec syntax ────────────────────────────────────────
validate_registry_syntax() {
  section "Checking host spec syntax"
  local host_spec="$REPO_DIR/hosts/${HOST}.nix"

  local err
  if command -v nix-instantiate >/dev/null 2>&1; then
    if ! err=$(nix-instantiate --parse "$host_spec" 2>&1 >/dev/null); then
      die "Host spec has a syntax error — stopping before any deploy step:
${err}

Open ${host_spec} and check the entry for '${HOST}' for a stray brace."
    fi
  else
    warn "nix-instantiate not found — skipping syntax check"
  fi

  log "Host spec parses cleanly"
}

# ── Step 10: Optimize BTRFS (single NVMe) ───────────────────────────────────
optimize_btrfs() {
  section "Optimizing BTRFS filesystem"
  if ! command -v btrfs >/dev/null 2>&1; then
    warn "btrfs not found — skipping filesystem optimization"
    return
  fi

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

# ── Step 11: Install format hook ─────────────────────────────────────────────
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

# ── Step 12: Validate flake ─────────────────────────────────────────────────
validate_flake() {
  section "Validating flake"
  note "Running flake check (no build)"
  ( cd "$REPO_DIR" && nix flake check --no-build ) || warn "flake check found issues — continuing"

  note "Evaluating nixosConfigurations.${HOST} (dry-run)"
  local drv
  drv=$( cd "$REPO_DIR" && nix eval --raw ".#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath" 2>/dev/null ) || {
    warn "Config evaluation failed — check for errors above"
    return
  }
  log "Config evaluates cleanly → ${drv}"
}

# ── Step 13: Switch system ───────────────────────────────────────────────────
switch_system() {
  section "Running nixos-rebuild switch"
  note "Target: ${HOST}"
  if ! command -v nixos-rebuild >/dev/null 2>&1; then
    warn "nixos-rebuild not on PATH — resolving via default profile"
    export PATH="/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:$PATH"
  fi
  sudo nixos-rebuild switch \
    --option experimental-features "$NIX_FEATURES" \
    --flake "$REPO_DIR#${HOST}"
  log "System switched to the new configuration"
}

# ── Step 14: Validate SOPS secrets ──────────────────────────────────────────
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

# ── Step 15: Generate SSH keys ───────────────────────────────────────────────
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

# ── Post-install ─────────────────────────────────────────────────────────────
post_install() {
  printf '\n%s╔══════════════════════════════════════════════════════════╗%s\n' "${C_GREEN}${C_BOLD}" "${C_RESET}"
  printf '%s║%s  ✓ Install complete                                       %s║%s\n' "${C_GREEN}${C_BOLD}" "${C_RESET}" "${C_GREEN}${C_BOLD}" "${C_RESET}"
  printf '%s╚══════════════════════════════════════════════════════════╝%s\n\n' "${C_GREEN}${C_BOLD}" "${C_RESET}"

  printf '  %sHost%s     %s\n'    "${C_DIM}" "${C_RESET}" "$HOST"
  printf '  %sUser%s     %s\n'    "${C_DIM}" "${C_RESET}" "$USER_NAME"
  printf '  %sDesktop%s  %s\n'    "${C_DIM}" "${C_RESET}" "$DESKTOP"
  printf '  %sRepo%s     %s\n\n'  "${C_DIM}" "${C_RESET}" "$REPO_DIR"

  if [[ "$USER_NAME" != "$(whoami)" ]]; then
    warn "Host user '${USER_NAME}' differs from the current user '$(whoami)'."
    warn "After the switch creates '${USER_NAME}', copy the age key into their home:"
    warn "  sudo install -Dm0600 $HOME/.config/sops/age/keys.txt /home/${USER_NAME}/.config/sops/age/keys.txt"
    printf '\n'
  fi

  printf '%sNext steps%s\n' "${C_BOLD}" "${C_RESET}"
  cat <<EOF
  1. Reboot to load all services:
       sudo reboot

  2. After reboot, verify the Wayland session:
       echo \$XDG_SESSION_TYPE    # should say "wayland"

  3. Bring up Tailscale:
       sudo tailscale up --ssh

  4. Verify the desktop stack:
       gnome-terminal --version  # default terminal
       nautilus --version        # file manager
       super + enter             # launch the terminal
       super + b                 # launch the browser

  5. Add your SSH public key to GitHub and GitLab:
       GitHub: https://github.com/settings/ssh/new
       GitLab: https://gitlab.com/-/user_settings/ssh_keys

  6. Test SSH connections:
       ssh -T git@github.com
       ssh -T git@gitlab.com

  7. Verify the Telegram bot:
       systemctl status ivali-bot-go

  8. Commit and push the generated files (GitLab is the source of truth):
       cd "$REPO_DIR"
       git status          # review what the installer changed
       git add .sops.yaml hosts/${HOST}.nix hosts/${HOST}/hardware-configuration.nix secrets/hosts/${HOST}.yaml
       git commit -m "chore: add host configuration for $HOST"
       git push origin main

EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  banner
  require_nixos
  detect_identity
  enable_nix_features
  install_tools
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
