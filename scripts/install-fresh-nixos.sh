#!/usr/bin/env bash
# install-fresh-nixos.sh — NixOS + GNOME bootstrap
#
# Bootstrap a freshly installed NixOS machine with the desktop and
# infrastructure flake. Designed to run on a new NixOS system (as your normal
# user with sudo). The script:
#
#   1. Pre-flight checks (disk, network, NixOS version)
#   2. Enable nix-command + flakes, and tune parallel downloads
#   3. SSH setup FIRST (key, agent, pinned host keys, ~/.ssh/config)
#   4. Register the key with GitLab (API when a token is given, else guided)
#   5. Verify SSH auth to the forge, then clone the repo
#   6. Detect hardware
#   7. Age key setup:
#      - --migrate: copy from --age-key-file / AGE_KEY env / interactive paste
#      - --fresh: generate new age key, create .sops.yaml entries, warn re-encrypt needed
#   8. Register host spec (including this machine's public key)
#   9. Stage generated files in git — Nix cannot see untracked files
#   10. Validate flake + syntax + formatting + architecture
#   11. Build the system closure, then nixos-rebuild switch
#   12. Post-switch: propagate credentials, validate SOPS, verify sshd + system
#
# Usage:
#   The repo is private, so it cannot be fetched over plain HTTPS/raw on a
#   fresh system. Save this script to a USB stick, then run:
#
#   For fresh install (new age key):
#     bash install-fresh-nixos.sh --fresh
#
#   For migrating from existing system (existing age key):
#     bash install-fresh-nixos.sh --migrate --age-key-file /path/to/keys.txt
#
#   Fully unattended (key already on GitLab, or a token to upload it):
#     GITLAB_TOKEN=glpat-... bash install-fresh-nixos.sh --fresh --yes
#
# Flags:
#   --host NAME              Host name (default: current hostname)
#   --user NAME              Username (default: current user)
#   --desktop gnome          Desktop environment (default: gnome)
#   --repo-url URL           Git clone URL (default: git@gitlab.com:... over SSH)
#   --push-url URL           Git push URL
#   --branch BRANCH          Git branch (default: main)
#   --age-key-file PATH      Path to an existing age key file (migrate mode)
#   --ssh-email EMAIL        Email for SSH key comment (default: itsivali@outlook.com)
#   --ssh-key PATH           SSH private key path (default: ~/.ssh/id_ed25519)
#   --gitlab-token TOKEN     GitLab PAT with `api` scope; uploads the SSH key for you
#   --no-authorize-local-key Do not add this machine's key to sshAuthorizedKeys
#   --no-ssh-config          Do not manage the ~/.ssh/config block
#   --download-jobs N        Parallel substitution (download) jobs
#   --http-connections N     HTTP connections to the substituters
#   --yes, -y                Non-interactive mode
#   --tailnet-domain         Tailscale domain (default: codlet-trench.ts.net)
#   --ssh-keys KEYS          Comma-separated SSH public keys
#   --no-ssh-keys            Skip SSH key generation
#   --features LIST          Comma-separated features (default: secrets,bitwarden,gitlab-runner,tailscale,tailscale-exit-node,ssh)
#   --migrate                Use existing age key (default mode)
#   --fresh                  Generate new age key (fresh install mode)
#   --no-secrets             Disable SOPS secrets for initial bootstrap
#   --build-only             Build the configuration but do not activate it
#   --no-rebuild             Stop before build/switch (for CI/testing)
#   --commit                 Commit the generated host files locally (no push)
#   --optimize-btrfs         Run a BTRFS balance + fstrim after install
#   --log-file PATH          Install log (default: ~/.local/state/ivali/install-<ts>.log)
#   --help, -h               Show this help
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
# Private repo: clone over SSH (requires the key registered with GitLab first).
# Override with --repo-url if you need HTTPS (e.g. a deploy token).
REPO_URL="${REPO_URL:-git@gitlab.com:willisivali/nixos-infrastructure.git}"
GIT_PUSH_URL="${GIT_PUSH_URL:-git@gitlab.com:willisivali/nixos-infrastructure.git}"
REPO_DIR="${REPO_DIR:-$HOME/nixos-infrastructure}"
BRANCH="${BRANCH:-main}"
NIX_FEATURES="nix-command flakes"

# ── Parallel downloads ───────────────────────────────────────────────────────
# Substitution is network-bound, so these sit well above core count. Defaults
# must match nix.settings in system/nix.nix, which takes over after the first
# switch. Nix defaults (16 jobs / 25 connections / 1 MiB buffer) leave a fast
# link idle for most of a fresh install.
DOWNLOAD_JOBS="${DOWNLOAD_JOBS:-32}"
HTTP_CONNECTIONS="${HTTP_CONNECTIONS:-50}"
DOWNLOAD_BUFFER_SIZE="${DOWNLOAD_BUFFER_SIZE:-268435456}"  # 256 MiB
NIX_TUNE_OPTS=()   # filled in by tune_nix_downloads

HOST="${HOST:-}"
USER_NAME="${USER_NAME:-}"
YES="${YES:-false}"
DESKTOP="${DESKTOP:-gnome}"
FEATURES="${FEATURES:-secrets,bitwarden,gitlab-runner,tailscale,tailscale-exit-node,ssh}"
TAILNET_DOMAIN="${TAILNET_DOMAIN:-codlet-trench.ts.net}"
SSH_KEYS="${SSH_KEYS:-}"
AGE_KEY_FILE="${AGE_KEY_FILE:-}"
SSH_EMAIL="${SSH_EMAIL:-itsivali@outlook.com}"
NO_SSH_KEYS="${NO_SSH_KEYS:-false}"
MODE="${MODE:-migrate}"  # migrate | fresh
NO_SECRETS="${NO_SECRETS:-false}"
NO_REBUILD="${NO_REBUILD:-false}"
BUILD_ONLY="${BUILD_ONLY:-false}"
RE_ENCRYPT="${RE_ENCRYPT:-false}"
OLD_AGE_KEY_FILE="${OLD_AGE_KEY_FILE:-}"
COMMIT="${COMMIT:-false}"
OPTIMIZE_BTRFS="${OPTIMIZE_BTRFS:-false}"

# ── SSH defaults ─────────────────────────────────────────────────────────────
SSH_DIR="$HOME/.ssh"
SSH_KEY="${SSH_KEY:-$SSH_DIR/id_ed25519}"
KNOWN_HOSTS="$SSH_DIR/known_hosts"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
AUTHORIZE_LOCAL_KEY="${AUTHORIZE_LOCAL_KEY:-true}"
MANAGE_SSH_CONFIG="${MANAGE_SSH_CONFIG:-true}"
SSH_PUBKEY=""            # filled in by setup_ssh_keys
BUILT_TOPLEVEL=""        # filled in by build_system
AUTHORIZED_KEYS=()       # filled in by collect_authorized_keys

# Pinned forge host keys. gitlab.com MUST stay in sync with ssh/client.nix
# (programs.ssh.knownHosts) — that module owns the post-switch system-wide set.
FORGE_HOSTS=(gitlab.com github.com)
# Read indirectly by forge_pinned_key() — not unused.
# shellcheck disable=SC2034
FORGE_KEY_gitlab_com="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf"
# shellcheck disable=SC2034
FORGE_KEY_github_com="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"

LOG_FILE="${LOG_FILE:-}"

# Kept for the log header: the option loop below consumes "$@".
SCRIPT_ARGS="$*"

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
    --ssh-key)         SSH_KEY="$2";   shift 2 ;;
    --gitlab-token)    GITLAB_TOKEN="$2"; shift 2 ;;
    --no-authorize-local-key) AUTHORIZE_LOCAL_KEY="false"; shift ;;
    --no-ssh-config)   MANAGE_SSH_CONFIG="false"; shift ;;
    --download-jobs)   DOWNLOAD_JOBS="$2"; shift 2 ;;
    --http-connections) HTTP_CONNECTIONS="$2"; shift 2 ;;
    --yes|-y)          YES="true";     shift ;;
    --tailnet-domain)  TAILNET_DOMAIN="$2"; shift 2 ;;
    --ssh-keys)        SSH_KEYS="$2";  shift 2 ;;
    --no-ssh-keys)     NO_SSH_KEYS="true"; shift ;;
    --features)        FEATURES="$2";  shift 2 ;;
    --migrate)         MODE="migrate"; shift ;;
    --fresh)           MODE="fresh";   shift ;;
    --no-secrets)      NO_SECRETS="true"; shift ;;
    --build-only)      BUILD_ONLY="true"; shift ;;
    --no-rebuild)      NO_REBUILD="true"; shift ;;
    --commit)          COMMIT="true"; shift ;;
    --optimize-btrfs)  OPTIMIZE_BTRFS="true"; shift ;;
    --log-file)        LOG_FILE="$2";  shift 2 ;;
    --re-encrypt)      RE_ENCRYPT="true"; shift ;;
    --old-age-key-file) OLD_AGE_KEY_FILE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: install-fresh-nixos.sh [OPTIONS]"
      echo ""
      echo "Identity"
      echo "  --host NAME              Host name (default: current hostname)"
      echo "  --user NAME              Username (default: current user)"
      echo "  --desktop TYPE           Desktop: gnome (default)"
      echo "  --tailnet-domain DOMAIN  Tailscale domain"
      echo ""
      echo "Repository"
      echo "  --repo DIR               Checkout path (default: ~/nixos-infrastructure)"
      echo "  --repo-url URL           Git clone URL (default: SSH git@gitlab.com:...)"
      echo "  --push-url URL           Git push URL"
      echo "  --branch BRANCH          Git branch (default: main)"
      echo "  --commit                 Commit the generated host files locally (no push)"
      echo ""
      echo "SSH"
      echo "  --ssh-key PATH           Private key path (default: ~/.ssh/id_ed25519)"
      echo "  --ssh-email EMAIL        Email used in the key comment"
      echo "  --ssh-keys KEYS          Extra authorized public keys (comma-separated)"
      echo "  --gitlab-token TOKEN     GitLab PAT with 'api' scope; uploads the key for you"
      echo "                           (or set GITLAB_TOKEN in the environment)"
      echo "  --no-authorize-local-key Do not add this machine's key to sshAuthorizedKeys"
      echo "  --no-ssh-config          Do not manage the ~/.ssh/config block"
      echo "  --no-ssh-keys            Skip SSH key generation entirely"
      echo ""
      echo "Secrets"
      echo "  --migrate                Use existing age key (default mode)"
      echo "  --fresh                  Generate new age key (fresh install mode)"
      echo "  --age-key-file PATH      Path to an existing age key file (migrate mode)"
      echo "  --no-secrets             Disable SOPS secrets for initial bootstrap"
      echo "  --re-encrypt             Re-encrypt all secrets with new key (requires --old-age-key-file)"
      echo "  --old-age-key-file PATH  Path to OLD age key for re-encryption (use with --re-encrypt)"
      echo ""
      echo "Install"
      echo "  --features LIST          Comma-separated feature flags"
      echo "  --download-jobs N        Parallel substitution jobs (default: ${DOWNLOAD_JOBS})"
      echo "  --http-connections N     HTTP connections to the substituters (default: ${HTTP_CONNECTIONS})"
      echo "  --build-only             Build the configuration but do not activate it"
      echo "  --no-rebuild             Stop before build/switch (for CI/testing)"
      echo "  --optimize-btrfs         Run a BTRFS balance + fstrim after install"
      echo "  --log-file PATH          Install log (default: ~/.local/state/ivali/install-<ts>.log)"
      echo "  --yes, -y                Non-interactive mode"
      echo "  --help, -h               Show this help"
      echo ""
      echo "Modes:"
      echo "  --migrate (default)      Copy existing age key from --age-key-file, AGE_KEY env, or interactive paste"
      echo "  --fresh                  Generate new age key, create placeholder secrets, warn about re-encryption"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Visual style ─────────────────────────────────────────────────────────────
# shellcheck disable=SC2034
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m';  C_BOLD=$'\033[1m';   C_DIM=$'\033[2m'
  C_BLUE=$'\033[1;34m'; C_CYAN=$'\033[1;36m'; C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_MAGENTA=$'\033[1;35m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_BLUE=''; C_CYAN=''
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_MAGENTA=''
fi

TOTAL_STEPS=0
STEP_NUM=0

banner() {
  printf '%s\n' "${C_CYAN}"
  cat <<'BANNER'
╔═══════════════════════════════════════════════════════════╗
║        NixOS + GNOME · Infrastructure Bootstrap         ║
╚══════════════════════════════════════════════════════════╝
BANNER
  printf '%s\n' "${C_RESET}"
}

# ── Logging ──────────────────────────────────────────────────────────────────
# Every status line is mirrored, colour-stripped, into $LOG_FILE so a failed
# run can be diagnosed after the fact. Long-running commands (build, switch,
# flake check) tee their own output into the same file.
logfile() {
  [[ -n "$LOG_FILE" ]] || return 0
  printf '%s %s\n' "$(date '+%H:%M:%S')" \
    "$(printf '%s' "$*" | sed $'s/\033\\[[0-9;]*m//g')" >> "$LOG_FILE" 2>/dev/null || true
}

section() {
  STEP_NUM=$((STEP_NUM + 1))
  printf '\n%s┌─ [%02d/%02d] %s%s\n' "${C_CYAN}${C_BOLD}" "$STEP_NUM" "$TOTAL_STEPS" "$*" "${C_RESET}"
  logfile "== [${STEP_NUM}/${TOTAL_STEPS}] $*"
}
log()  { printf '%s│%s  %s✓%s %s\n' "${C_CYAN}" "${C_RESET}" "${C_GREEN}" "${C_RESET}" "$*"; logfile "   OK   $*"; }
note() { printf '%s│%s  %s· %s%s\n' "${C_CYAN}" "${C_RESET}" "${C_DIM}" "$*" "${C_RESET}"; logfile "   ..   $*"; }
warn() { printf '%s│%s  %s⚠ WARN%s  %s\n' "${C_CYAN}" "${C_RESET}" "${C_YELLOW}" "${C_RESET}" "$*" >&2; logfile "   WARN $*"; }
die()  {
  printf '%s│%s  %s✗ ERROR%s %s\n\n' "${C_CYAN}" "${C_RESET}" "${C_RED}" "${C_RESET}" "$*" >&2
  logfile "   FAIL $*"
  [[ -n "$LOG_FILE" ]] && printf '  %sLog:%s %s\n\n' "${C_DIM}" "${C_RESET}" "$LOG_FILE" >&2
  exit 1
}

start_logging() {
  if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="$HOME/.local/state/ivali/install-$(date '+%Y%m%d-%H%M%S').log"
  fi
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || { LOG_FILE=""; return 0; }
  : > "$LOG_FILE" 2>/dev/null || { LOG_FILE=""; return 0; }
  logfile "install-fresh-nixos.sh ${SCRIPT_ARGS} (mode=${MODE})"
}

# ── Prompting ────────────────────────────────────────────────────────────────
# Reads straight from /dev/tty so prompts keep working when stdin is a pipe
# (`curl ... | bash`) and so they never land in the log file.
interactive() { [[ "$YES" != "true" && -r /dev/tty ]]; }

ask() { # ask <varname> <prompt>
  local __var="$1" __prompt="$2" __reply=""
  if interactive; then
    printf '%s│%s  %s' "${C_CYAN}" "${C_RESET}" "$__prompt" > /dev/tty
    IFS= read -r __reply < /dev/tty || __reply=""
  fi
  printf -v "$__var" '%s' "$__reply"
}

pause() { # pause <prompt>
  local _ignored
  interactive || return 0
  ask _ignored "$1"
}

# ── Nix wrappers ─────────────────────────────────────────────────────────────
# Every nix invocation in this script carries the download tuning, so the
# bootstrap downloads in parallel before system/nix.nix is active.
nix() {
  command nix --extra-experimental-features "$NIX_FEATURES" \
    "${NIX_TUNE_OPTS[@]}" "$@"
}

# Run a long command, mirroring its output into the install log.
run_logged() {
  if [[ -n "$LOG_FILE" ]]; then
    "$@" 2>&1 | tee -a "$LOG_FILE"
  else
    "$@"
  fi
}

# ── Step: Validate environment ───────────────────────────────────────────────
require_nixos() {
  section "Validating environment"
  [[ -f /etc/NIXOS ]] || die "This script must run on NixOS."
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
  [[ "$(id -u)" -ne 0 ]] || die "Run as your normal user, not root."
  log "Running on NixOS as a regular user with sudo access"
  if [[ -n "$LOG_FILE" ]]; then note "Log: $LOG_FILE"; fi
}

# ── Step: Pre-flight checks ──────────────────────────────────────────────────
preflight_checks() {
  section "Pre-flight checks"

  # Check disk space (need at least 5GB free)
  local avail_kb
  avail_kb=$(df --output=avail "$HOME" | tail -1)
  local avail_gb=$((avail_kb / 1024 / 1024))
  if [[ "$avail_gb" -lt 5 ]]; then
    warn "Low disk space: ${avail_gb}GB available (need 5GB+)"
  else
    log "Disk space: ${avail_gb}GB available"
  fi

  # Check internet connectivity
  if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    log "Internet connectivity: OK"
  else
    warn "No internet connectivity — some steps may fail"
  fi

  # Check NixOS version
  local nixos_ver
  nixos_ver=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
  log "NixOS version: ${nixos_ver}"

  # Check if running on expected architecture
  local arch
  arch=$(uname -m)
  log "Architecture: ${arch}"
}

# ── Step: Detect or prompt for host/user ─────────────────────────────────────
detect_identity() {
  section "Identifying host"
  if [[ -z "$HOST" ]]; then
    HOST=$(hostname -s 2>/dev/null || echo "laptop")
    local input_host
    ask input_host "Host name [$HOST]: "
    HOST="${input_host:-$HOST}"
  fi

  if [[ -z "$USER_NAME" ]]; then
    USER_NAME=$(whoami)
    local input_user
    ask input_user "Username [$USER_NAME]: "
    USER_NAME="${input_user:-$USER_NAME}"
  fi

  log "host=${C_BOLD}${HOST}${C_RESET}  user=${C_BOLD}${USER_NAME}${C_RESET}  desktop=${C_BOLD}${DESKTOP}${C_RESET}"
}

# ── Step: Enable nix features ────────────────────────────────────────────────
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

# Replace or append a single setting in the user's nix.conf.
set_user_nix_setting() { # set_user_nix_setting <key> <value>
  local conf="$HOME/.config/nix/nix.conf" key="$1" val="$2"
  mkdir -p "$(dirname "$conf")"
  touch "$conf"
  if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$conf"; then
    sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${val}|" "$conf"
  else
    printf '%s = %s\n' "$key" "$val" >> "$conf"
  fi
}

# Substitution settings are applied by the nix *daemon*, which only honours
# client-supplied values for a trusted user. On stock NixOS that is root
# alone, so before the first switch the operator's own `nix build` may fall
# back to the defaults while the sudo-run steps still get the tuning.
nix_user_is_trusted() {
  local trusted entry
  trusted="$(command nix --extra-experimental-features nix-command \
    config show trusted-users 2>/dev/null \
    || sed -nE 's/^[[:space:]]*trusted-users[[:space:]]*=[[:space:]]*//p' /etc/nix/nix.conf 2>/dev/null)"
  [[ -n "$trusted" ]] || return 1

  for entry in $trusted; do
    [[ "$entry" == "$(whoami)" ]] && return 0
    if [[ "$entry" == @* ]] && id -nG | tr ' ' '\n' | grep -qx "${entry#@}"; then
      return 0
    fi
  done
  return 1
}

# ── Step: Tune parallel downloads ────────────────────────────────────────────
# A fresh install pulls thousands of store paths; wall-clock is dominated by
# substitution, not by building. Nix's defaults (16 jobs, 25 connections, a
# 1 MiB download buffer that stalls every job once full) leave a fast link
# mostly idle.
tune_nix_downloads() {
  section "Tuning parallel downloads"

  NIX_TUNE_OPTS=(
    --option max-substitution-jobs "$DOWNLOAD_JOBS"
    --option http-connections "$HTTP_CONNECTIONS"
    --option download-buffer-size "$DOWNLOAD_BUFFER_SIZE"
    --option connect-timeout 5
    --option stalled-download-timeout 30
  )

  # Persist for this user's future nix calls too, not just this run.
  set_user_nix_setting max-substitution-jobs "$DOWNLOAD_JOBS"
  set_user_nix_setting http-connections "$HTTP_CONNECTIONS"
  set_user_nix_setting download-buffer-size "$DOWNLOAD_BUFFER_SIZE"

  # NIX_CONFIG covers the nix-env fallback in install_tools, which takes no
  # --option flags.
  export NIX_CONFIG="experimental-features = ${NIX_FEATURES}
max-substitution-jobs = ${DOWNLOAD_JOBS}
http-connections = ${HTTP_CONNECTIONS}
download-buffer-size = ${DOWNLOAD_BUFFER_SIZE}"

  log "${DOWNLOAD_JOBS} parallel download jobs, ${HTTP_CONNECTIONS} HTTP connections, $((DOWNLOAD_BUFFER_SIZE / 1024 / 1024))MiB buffer"

  if nix_user_is_trusted; then
    log "$(whoami) is a trusted nix user — the settings apply to every step"
  else
    warn "$(whoami) is not a trusted nix user yet, so the daemon ignores these for"
    warn "user-run commands. The sudo-run switch still gets them, and"
    warn "system/nix.nix makes them permanent after the first rebuild."
  fi
}

# ── Step: Install git, age, sops (bootstrap prerequisites) ───────────────────
install_tools() {
  section "Installing bootstrap tools (git, age, sops)"
  note "This installs into your Nix user profile; the flake also ships them system-wide after the first switch."

  # Make the bootstrap profile available for the rest of this session.
  export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

  local required=(git age sops)
  # curl is only needed for the GitLab key-upload API call.
  if [[ -n "$GITLAB_TOKEN" ]]; then required+=(curl); fi

  local missing="" pkg probe
  for pkg in "${required[@]}"; do
    probe="$pkg"
    if [[ "$pkg" == "age" ]]; then probe="age-keygen"; fi
    command -v "$probe" >/dev/null 2>&1 || missing+=" nixpkgs#${pkg}"
  done
  missing="${missing## }"

  if [[ -z "$missing" ]]; then
    log "git, age, and sops already available"
    return
  fi

  note "Installing: ${missing}"
  # shellcheck disable=SC2086  # intentional word splitting of the flake refs
  if ! nix profile install $missing; then
    warn "nix profile install failed — falling back to nix-env"
    local attrs=()
    for pkg in $missing; do
      attrs+=("-A" "nixpkgs.${pkg#nixpkgs#}")
    done
    nix-env -i "${attrs[@]}" || warn "nix-env fallback failed too"
  fi
  log "Bootstrap tools installed into $HOME/.nix-profile"

  command -v git >/dev/null 2>&1 || die "git is required (install failed)"
  command -v age-keygen >/dev/null 2>&1 || warn "age-keygen not found — age key validation will be limited"
  command -v sops >/dev/null 2>&1 || warn "sops not found — secret re-encryption step will be skipped"
}

##############################################################################
# SSH
##############################################################################

# Tighten everything under ~/.ssh — OpenSSH refuses to use a world-readable
# private key, and a loose ~/.ssh silently breaks the clone.
harden_ssh_permissions() {
  [[ -d "$SSH_DIR" ]] || return 0
  chmod 700 "$SSH_DIR"
  find "$SSH_DIR" -maxdepth 1 -type f \( -name 'id_*' -o -name '*_key' \) \
    ! -name '*.pub' -exec chmod 600 {} + 2>/dev/null || true
  find "$SSH_DIR" -maxdepth 1 -type f -name '*.pub' -exec chmod 644 {} + 2>/dev/null || true
  local f
  for f in config known_hosts authorized_keys; do
    if [[ -f "$SSH_DIR/$f" ]]; then chmod 600 "$SSH_DIR/$f"; fi
  done
  return 0
}

# ── Step: SSH keys + agent ───────────────────────────────────────────────────
setup_ssh_keys() {
  section "Setting up SSH keys"
  if [[ "$NO_SSH_KEYS" == "true" ]]; then
    note "Skipping SSH key generation (--no-ssh-keys)"
    return
  fi

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  if [[ -f "$SSH_KEY" ]]; then
    log "Using existing key: ${SSH_KEY}"
  else
    # -a 100 KDF rounds hardens the (unencrypted) private key at rest; the key
    # must stay passphrase-less so the unattended clone and GitOps pulls work.
    ssh-keygen -t ed25519 -a 100 -C "${SSH_EMAIL} (${USER_NAME}@${HOST})" -f "$SSH_KEY" -N "" >/dev/null || {
      warn "SSH key generation failed — check: ssh-keygen available?"
      return
    }
    log "SSH key generated: ${SSH_KEY}"
  fi

  # Recover a missing .pub from the private key rather than failing later.
  if [[ ! -f "${SSH_KEY}.pub" ]]; then
    ssh-keygen -y -f "$SSH_KEY" > "${SSH_KEY}.pub" || warn "Could not derive public key from ${SSH_KEY}"
  fi

  harden_ssh_permissions

  if [[ -f "${SSH_KEY}.pub" ]]; then
    SSH_PUBKEY="$(cat "${SSH_KEY}.pub")"
    note "Fingerprint: $(ssh-keygen -lf "${SSH_KEY}.pub" 2>/dev/null || echo unknown)"
  fi

  # Load the key into an agent so repeated git/ssh calls in this run are cheap.
  # GNOME's keyring takes over after the switch (programs.ssh.startAgent = false).
  if [[ -z "${SSH_AUTH_SOCK:-}" ]] && command -v ssh-agent >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    note "Started a temporary ssh-agent for this run"
  fi
  if ssh-add "$SSH_KEY" >/dev/null 2>&1; then
    log "Key loaded into ssh-agent"
  else
    note "ssh-agent unavailable — ssh will read the key file directly"
  fi

  # Display public key for the operator to add to GitLab.
  printf '\n%s│%s  %s┌────────────────────────────────────────┐%s\n' "${C_CYAN}" "${C_RESET}" "${C_MAGENTA}" "${C_RESET}"
  printf '%s│%s  %s│  SSH Public Key (add to GitLab)        │%s\n' "${C_CYAN}" "${C_RESET}" "${C_MAGENTA}" "${C_RESET}"
  printf '%s│%s  %s└────────────────────────────────────────┘%s\n' "${C_CYAN}" "${C_RESET}" "${C_MAGENTA}" "${C_RESET}"
  printf '%s│%s  %s\n' "${C_CYAN}" "${C_RESET}" "${SSH_PUBKEY:-<none>}"
  printf '%s│%s\n' "${C_CYAN}" "${C_RESET}"
}

# Host of the SSH remote in --repo-url (empty when the URL is not SSH).
repo_ssh_host() {
  local url="$REPO_URL"
  case "$url" in
    ssh://*)
      url="${url#ssh://}"; url="${url#*@}"; url="${url%%/*}"
      printf '%s' "${url%%:*}"
      ;;
    *@*:*)
      url="${url#*@}"
      printf '%s' "${url%%:*}"
      ;;
  esac
}

# Pinned key for a forge host, looked up via a name-mangled variable.
forge_pinned_key() { # forge_pinned_key <host>
  local var="FORGE_KEY_${1//[.-]/_}"
  printf '%s' "${!var:-}"
}

add_known_host() { # add_known_host <host>
  local host="$1" pinned
  pinned="$(forge_pinned_key "$host")"

  touch "$KNOWN_HOSTS"
  chmod 600 "$KNOWN_HOSTS"

  if ssh-keygen -F "$host" -f "$KNOWN_HOSTS" >/dev/null 2>&1; then
    note "known_hosts already trusts ${host}"
    return
  fi

  if [[ -n "$pinned" ]]; then
    # Pinned keys beat trust-on-first-use: no window for a MITM on a fresh box.
    printf '%s %s\n' "$host" "$pinned" >> "$KNOWN_HOSTS"
    log "Pinned host key for ${host}"
  elif ssh-keyscan -T 10 -t ed25519 "$host" >> "$KNOWN_HOSTS" 2>/dev/null; then
    warn "Scanned ${host} host key (trust-on-first-use — verify the fingerprint)"
  else
    warn "Could not obtain a host key for ${host}"
  fi
}

# ── Step: SSH client configuration ───────────────────────────────────────────
configure_ssh_client() {
  section "Configuring SSH client"

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  # Trust the forges before any git operation runs.
  for host in "${FORGE_HOSTS[@]}"; do
    add_known_host "$host"
  done
  local remote_host
  remote_host="$(repo_ssh_host)"
  if [[ -n "$remote_host" ]] && ! printf '%s\n' "${FORGE_HOSTS[@]}" | grep -qx "$remote_host"; then
    add_known_host "$remote_host"
  fi

  if [[ "$MANAGE_SSH_CONFIG" != "true" ]]; then
    note "Leaving ~/.ssh/config untouched (--no-ssh-config)"
    harden_ssh_permissions
    return
  fi
  if [[ "$NO_SSH_KEYS" == "true" && ! -f "$SSH_KEY" ]]; then
    note "No managed key — skipping ~/.ssh/config block"
    harden_ssh_permissions
    return
  fi

  # Only the pre-switch essentials live here: which key to use for the forges
  # and the tailnet. Global client hardening (ciphers, keepalive) is declared
  # in ssh/client.nix and applies system-wide after the first switch.
  local cfg="$SSH_DIR/config"
  local begin="# >>> managed by scripts/install-fresh-nixos.sh >>>"
  local end="# <<< managed by scripts/install-fresh-nixos.sh <<<"
  local block
  block="${begin}
# Edit the script, not this block — it is rewritten on every bootstrap run.
Host gitlab.com
    User git
    IdentityFile ${SSH_KEY}
    IdentitiesOnly yes
    AddKeysToAgent yes
    PreferredAuthentications publickey

Host github.com
    User git
    IdentityFile ${SSH_KEY}
    IdentitiesOnly yes
    AddKeysToAgent yes
    PreferredAuthentications publickey
"
  if [[ -n "$TAILNET_DOMAIN" ]]; then
    block+="
Host *.${TAILNET_DOMAIN}
    User ${USER_NAME}
    IdentityFile ${SSH_KEY}
    IdentitiesOnly yes
    ForwardAgent no
"
  fi
  block+="${end}"

  touch "$cfg"
  if grep -qF "$begin" "$cfg"; then
    # Replace the previous block in place — keeps hand-written entries intact.
    local tmp
    tmp="$(mktemp "${cfg}.XXXXXX")"
    awk -v b="$begin" -v e="$end" '
      index($0, b) == 1 { skip = 1 }
      !skip { print }
      index($0, e) == 1 { skip = 0 }
    ' "$cfg" > "$tmp"
    printf '%s\n' "$block" >> "$tmp"
    mv "$tmp" "$cfg"
    log "Refreshed the managed block in ~/.ssh/config"
  else
    printf '\n%s\n' "$block" >> "$cfg"
    log "Added a managed block to ~/.ssh/config"
  fi

  harden_ssh_permissions
  log "Permissions hardened under ~/.ssh"
}

# ── Step: Register the key with GitLab ───────────────────────────────────────
register_gitlab_ssh_key() {
  section "Registering the SSH key with GitLab"

  local forge
  forge="$(repo_ssh_host)"
  if [[ -z "$forge" ]]; then
    log "Using a non-SSH repo URL — nothing to register"
    return
  fi
  if [[ -z "$SSH_PUBKEY" ]]; then
    note "No managed public key — skipping registration"
    return
  fi

  if [[ -n "$GITLAB_TOKEN" ]] && command -v curl >/dev/null 2>&1; then
    local api="https://${forge}/api/v4"
    local key_body
    key_body="$(printf '%s' "$SSH_PUBKEY" | awk '{print $2}')"

    if curl -fsS --max-time 20 -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "${api}/user/keys" 2>/dev/null \
      | grep -qF "$key_body"; then
      log "Key is already registered on ${forge}"
      return
    fi

    # Public keys contain no quotes or backslashes, so inlining is safe here.
    local payload response
    payload="{\"title\":\"${HOST}\",\"key\":\"${SSH_PUBKEY}\",\"usage_type\":\"auth\"}"
    if response="$(curl -fsS --max-time 20 \
      -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$payload" \
      "${api}/user/keys" 2>&1)"; then
      log "Key uploaded to ${forge} via the API"
      return
    fi
    if printf '%s' "$response" | grep -qi 'already been taken'; then
      log "Key is already registered on ${forge}"
      return
    fi
    warn "API upload failed — falling back to the manual flow"
    note "$(printf '%s' "$response" | head -2)"
  elif [[ -n "$GITLAB_TOKEN" ]]; then
    warn "curl not available — falling back to the manual flow"
  fi

  note "Add the public key above to ${forge}:"
  note "  https://${forge}/-/user_settings/ssh_keys"
  if command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    xdg-open "https://${forge}/-/user_settings/ssh_keys" >/dev/null 2>&1 &
  fi
  if ! interactive; then
    note "Non-interactive mode — assuming the key is already registered"
    note "Tip: pass --gitlab-token (or GITLAB_TOKEN=...) to upload it automatically"
    return
  fi
  pause "Press ENTER once the key is added (Ctrl+C to abort): "
}

# ── Step: Verify SSH auth to the forge ───────────────────────────────────────
# A real authentication probe beats "press ENTER when done" — it catches a
# mistyped key, a wrong account, or a missing key before the clone fails.
verify_forge_ssh() {
  section "Verifying SSH access to the forge"

  local forge
  forge="$(repo_ssh_host)"
  if [[ -z "$forge" ]]; then
    log "Using a non-SSH repo URL — nothing to verify"
    return
  fi

  local attempt=1 max=5 out
  while :; do
    out="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -T "git@${forge}" 2>&1 || true)"
    if printf '%s' "$out" | grep -qiE 'Welcome to GitLab|successfully authenticated'; then
      log "SSH authentication to ${forge} works: $(printf '%s' "$out" | head -1)"
      return
    fi

    note "$(printf '%s' "$out" | head -2)"
    if ! interactive || [[ "$attempt" -ge "$max" ]]; then
      warn "Could not authenticate to ${forge} as git — the clone may fail"
      warn "Add the key shown above, or re-run with --repo-url https://<token>@${forge}/..."
      return
    fi
    attempt=$((attempt + 1))
    pause "Not authenticated yet. Press ENTER to retry (${attempt}/${max}): "
  done
}

# ── Step: Clone or update repo ───────────────────────────────────────────────
clone_or_update_repo() {
  section "Fetching infrastructure repo"
  note "$REPO_URL"

  if [[ -d "$REPO_DIR/.git" ]]; then
    git -C "$REPO_DIR" fetch --prune origin "$BRANCH" || die "git fetch failed — check SSH access to $(repo_ssh_host)"
    git -C "$REPO_DIR" checkout "$BRANCH"
    git -C "$REPO_DIR" merge --ff-only "origin/$BRANCH" || warn "Could not fast-forward ${BRANCH} — local commits present"
  else
    mkdir -p "$(dirname "$REPO_DIR")"
    # Full clone, not --depth 1: the flake is evaluated from the git tree and
    # the GitOps reconciler needs real history to fetch, diff, and roll back.
    git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR" \
      || die "git clone failed — verify the SSH key is registered on $(repo_ssh_host)"
  fi
  git -C "$REPO_DIR" remote set-url --push origin "$GIT_PUSH_URL"
  log "Repo ready at $REPO_DIR (branch: $BRANCH)"
}

# ── Step: Detect hardware ────────────────────────────────────────────────────
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

# ── Step: Install SOPS age key ───────────────────────────────────────────────
setup_age_key() {
  section "Installing SOPS age key"
  local key_dir="$HOME/.config/sops/age"
  local key_file="$key_dir/keys.txt"

  if [[ "$MODE" == "fresh" ]]; then
    # --fresh mode: generate new age key
    note "Mode: --fresh (generating new age key)"
    if [[ -f "$key_file" ]] && grep -q 'AGE-SECRET-KEY-' "$key_file"; then
      note "Age key already present at $key_file — leaving it untouched"
    else
      command -v age-keygen >/dev/null 2>&1 || die "age-keygen not found — install age first (run install_tools)"
      mkdir -p "$key_dir"
      age-keygen > "$key_file" || die "Failed to generate age key"
      chmod 700 "$key_dir"
      chmod 600 "$key_file"
      log "New age key generated at $key_file"
    fi

    # Register the new key in .sops.yaml
    register_sops_key

    # Warn about re-encryption
    warn "══════════════════════════════════════════════════════════════"
    warn "FRESH MODE: New age key generated — secrets are NOT encrypted for this key!"
    warn "You MUST re-encrypt secrets from a machine with the old key:"
    warn "  1. Add this key's public key to .sops.yaml (done above)"
    warn "  2. From old machine: sops -e -i secrets/*.yaml"
    warn "  3. Push changes, then rebuild on this machine"
    warn "══════════════════════════════════════════════════════════════"
    return
  fi

  # --migrate mode (default): copy existing age key
  note "Mode: --migrate (using existing age key)"
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
  elif ! interactive; then
    warn "Non-interactive mode and no age key source — skipping"
    warn "Provide --age-key-file or AGE_KEY env var"
    return
  else
    note "No age key source found — paste your existing age key"
    note "Get it from: cat ~/.config/sops/age/keys.txt (on your old system)"
    mkdir -p "$key_dir"
    printf '%s│%s  Paste the entire AGE-SECRET-KEY-... line, then press Ctrl+D:\n' "${C_CYAN}" "${C_RESET}" > /dev/tty
    cat < /dev/tty > "$key_file" || {
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

# ── Re-encrypt secrets with new age key ──────────────────────────────────────
re_encrypt_secrets() {
  section "Re-encrypting secrets with new age key"

  [[ -n "$OLD_AGE_KEY_FILE" ]] || die "--re-encrypt requires --old-age-key-file"
  [[ -f "$OLD_AGE_KEY_FILE" ]] || die "Old age key file not found: $OLD_AGE_KEY_FILE"

  command -v sops >/dev/null 2>&1 || die "sops not found — install sops first"

  # Both keys must be in .sops.yaml for re-encryption to work
  local new_key_file="$HOME/.config/sops/age/keys.txt"
  [[ -f "$new_key_file" ]] || die "New age key not found at $new_key_file"

  # Create a temporary sops.yaml with both keys
  local sops_yaml="$REPO_DIR/.sops.yaml"
  [[ -f "$sops_yaml" ]] || die ".sops.yaml not found in repo"

  note "Re-encrypting all secrets in secrets/..."
  cd "$REPO_DIR"

  # Export both keys for sops
  export SOPS_AGE_KEY_FILE="$OLD_AGE_KEY_FILE"
  export SOPS_AGE_RECIPIENTS_FILE="$new_key_file"

  # Re-encrypt all secret files
  local secret_files
  secret_files=$(find secrets -name "*.yaml" -type f 2>/dev/null | head -20)
  if [[ -z "$secret_files" ]]; then
    warn "No secret files found in secrets/"
    return
  fi

  for secret in $secret_files; do
    note "Re-encrypting $secret"
    if sops -e -i "$secret"; then
      log "Re-encrypted: $secret"
    else
      warn "Failed to re-encrypt: $secret (may not be encrypted yet)"
    fi
  done

  unset SOPS_AGE_KEY_FILE
  unset SOPS_AGE_RECIPIENTS_FILE
  log "Re-encryption complete"
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

# Public keys that go into the host spec: --ssh-keys plus (by default) this
# machine's own key, so the operator can reach the host over the tailnet.
collect_authorized_keys() {
  AUTHORIZED_KEYS=()
  local key
  if [[ -n "$SSH_KEYS" ]]; then
    local parsed=()
    IFS=',' read -ra parsed <<< "$SSH_KEYS"
    for key in "${parsed[@]}"; do
      key="${key#"${key%%[![:space:]]*}"}"   # ltrim
      key="${key%"${key##*[![:space:]]}"}"   # rtrim
      [[ -n "$key" ]] && AUTHORIZED_KEYS+=("$key")
    done
  fi
  if [[ "$AUTHORIZE_LOCAL_KEY" == "true" && -n "$SSH_PUBKEY" ]]; then
    local material existing dup=false
    material="$(printf '%s' "$SSH_PUBKEY" | awk '{print $2}')"
    for existing in "${AUTHORIZED_KEYS[@]}"; do
      if [[ "$existing" == *"$material"* ]]; then dup=true; fi
    done
    if [[ "$dup" != "true" ]]; then AUTHORIZED_KEYS+=("$SSH_PUBKEY"); fi
  fi
  return 0
}

# ── Step: Register host ──────────────────────────────────────────────────────
# NOTE: This host spec template must stay in sync with
# internal/commands/bootstrap_host.go:generateHostSpec().
register_host() {
  section "Creating host spec: hosts/${HOST}.nix"

  local host_spec="$REPO_DIR/hosts/${HOST}.nix"

  # Build feature flags
  local f_secrets="true" f_bitwarden="true" f_runner="true"
  local f_tailscale="true" f_exitnode="true" f_ssh="true"

  case ",${FEATURES}," in
    *,no-secrets,*)             f_secrets="false" ;;
    *,no-bitwarden,*)           f_bitwarden="false" ;;
    *,no-gitlab-runner,*)       f_runner="false" ;;
    *,no-tailscale,*)           f_tailscale="false" ;;
    *,no-tailscale-exit-node,*) f_exitnode="false" ;;
    *,no-ssh,*)                 f_ssh="false" ;;
  esac

  # Override secrets flag based on --no-secrets or fresh mode
  if [[ "$NO_SECRETS" == "true" || "$MODE" == "fresh" ]]; then
    f_secrets="false"
    if [[ "$MODE" == "fresh" ]]; then
      note "Fresh mode: disabling secrets for initial bootstrap (will enable after re-encryption)"
    fi
  fi

  # Authorized keys (Nix list items are whitespace-separated — no semicolons).
  collect_authorized_keys
  local keys_block="" key
  for key in "${AUTHORIZED_KEYS[@]}"; do
    keys_block+="    \"${key}\""$'\n'
  done

  local sops_key_path="${HOME}/.config/sops/age/keys.txt"

  # If the host spec already exists, offer to preserve it
  if [[ -f "$host_spec" ]]; then
    log "Host spec '${host_spec}' already exists"
    local overwrite
    ask overwrite "Overwrite existing host spec? [y/N]: "
    if [[ "${overwrite,,}" != "y" ]]; then
      note "Keeping the existing host spec"
      # The spec is authoritative; make sure this machine's key is in it.
      if [[ -n "$SSH_PUBKEY" && "$AUTHORIZE_LOCAL_KEY" == "true" ]] \
        && ! grep -qF "$(printf '%s' "$SSH_PUBKEY" | awk '{print $2}')" "$host_spec"; then
        warn "This machine's key is not in sshAuthorizedKeys — add it to ${host_spec}:"
        warn "  \"${SSH_PUBKEY}\""
      fi
      return 0
    fi
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
  if [[ "${#AUTHORIZED_KEYS[@]}" -gt 0 ]]; then
    log "sshAuthorizedKeys: ${#AUTHORIZED_KEYS[@]} key(s) declared for ${USER_NAME}"
  else
    warn "sshAuthorizedKeys is empty — inbound SSH will reject every key"
  fi
}

# ── Step: Stage generated files ──────────────────────────────────────────────
# Nix evaluates a flake from the *git tree*: files that are not in the index
# are invisible, so a freshly written hosts/<host>.nix would make
# nixosConfigurations.<host> "missing attribute" at build time.
stage_generated_files() {
  section "Staging generated files for flake evaluation"

  local paths=(
    ".sops.yaml"
    "hosts/${HOST}.nix"
    "hosts/${HOST}/hardware-configuration.nix"
    "secrets/hosts/${HOST}.yaml"
  )

  local staged=() p
  for p in "${paths[@]}"; do
    [[ -e "$REPO_DIR/$p" ]] && staged+=("$p")
  done

  if [[ "${#staged[@]}" -eq 0 ]]; then
    warn "Nothing to stage — expected generated host files are missing"
    return
  fi

  git -C "$REPO_DIR" add -- "${staged[@]}" \
    || die "git add failed — Nix cannot see untracked files, so the build would not find ${HOST}"

  for p in "${staged[@]}"; do
    note "staged ${p}"
  done
  log "${#staged[@]} file(s) staged (not committed — review with: git -C ${REPO_DIR} status)"
}

# ── Step: Validate host spec syntax ─────────────────────────────────────────
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

# ── Step: Install format hook ────────────────────────────────────────────────
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

# ── Step: Validate flake ────────────────────────────────────────────────────
validate_flake() {
  section "Validating flake"
  note "Running flake check (no build)"
  ( cd "$REPO_DIR" && nix flake check --no-build ) || warn "flake check found issues — continuing"

  note "Evaluating nixosConfigurations.${HOST} (dry-run)"
  local drv errors
  errors="$(mktemp)"
  if drv=$( cd "$REPO_DIR" && nix eval --raw \
    ".#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath" 2>"$errors" ); then
    rm -f "$errors"
    log "Config evaluates cleanly → ${drv}"
    return
  fi

  # An evaluation failure is a hard gate: never hand a broken config to
  # nixos-rebuild.
  warn "Config evaluation failed:"
  note "$(tail -5 "$errors")"
  rm -f "$errors"
  die "Cannot evaluate nixosConfigurations.${HOST} — fix the error above before deploying.
If it says 'attribute missing', the host files are not in the git index:
  git -C ${REPO_DIR} add hosts/${HOST}.nix hosts/${HOST}/"
}

# ── Step: Check Nix formatting ──────────────────────────────────────────────
check_nix_format() {
  section "Checking Nix formatting"
  if ( cd "$REPO_DIR" && nix fmt -- --check . ) >/dev/null 2>&1; then
    log "All .nix files properly formatted"
  else
    warn "Formatting issues found — run 'nix fmt' to fix"
    note "Continuing (non-blocking)"
  fi
}

# ── Step: Architecture linter ───────────────────────────────────────────────
check_architecture() {
  section "Running architecture linter"
  local checker="/tmp/check-architecture-install-bin"
  if ( cd "$REPO_DIR" && go build -o "$checker" ./cmd/check-architecture/ && "$checker" ) >/dev/null 2>&1; then
    log "Architecture validation passed"
  else
    warn "Architecture issues found — review before committing"
    note "Continuing (non-blocking)"
  fi
}

# ── Step: Build system closure ──────────────────────────────────────────────
# Build before activating: a failed build leaves the running system untouched,
# and the switch afterwards is a near-instant activation of the same closure.
build_system() {
  section "Building system closure for ${HOST}"
  note "This is the long step — everything after it is activation only"
  note "Fetching with ${DOWNLOAD_JOBS} parallel jobs over ${HTTP_CONNECTIONS} connections"

  # stderr is left on the terminal so the build progress stays visible.
  BUILT_TOPLEVEL=$( cd "$REPO_DIR" && nix build --no-link --print-out-paths \
    ".#nixosConfigurations.${HOST}.config.system.build.toplevel" ) || {
    die "Build failed. Re-run with full logs:
  cd ${REPO_DIR} && nix build -L .#nixosConfigurations.${HOST}.config.system.build.toplevel"
  }
  log "Built: ${BUILT_TOPLEVEL}"
}

# ── Step: Switch system ─────────────────────────────────────────────────────
switch_system() {
  section "Running nixos-rebuild switch"
  note "Target: ${HOST}"
  if ! command -v nixos-rebuild >/dev/null 2>&1; then
    warn "nixos-rebuild not on PATH — resolving via default profile"
    export PATH="/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:$PATH"
  fi

  local current
  current=$(readlink -f /run/current-system 2>/dev/null || echo "")

  # Root is always a trusted user, so the download tuning is honoured here
  # even when the operator's own account is not yet trusted.
  run_logged sudo nixos-rebuild switch \
    --option experimental-features "$NIX_FEATURES" \
    "${NIX_TUNE_OPTS[@]}" \
    --flake "$REPO_DIR#${HOST}" || {
    warn "Activation failed — the previous generation is still bootable"
    [[ -n "$current" ]] && note "Previous system: ${current}"
    die "nixos-rebuild switch failed. Recover with:
  sudo nixos-rebuild switch --rollback
  journalctl -b -u nixos-rebuild-switch-to-configuration --no-pager
Then re-run this script once the error is fixed."
  }
  log "System switched to the new configuration"
}

# ── Step: Propagate credentials to the target user ──────────────────────────
# When --user differs from the operator running the script, the switch creates
# that account with an empty ~/.ssh and no age key; copy both across so SOPS
# and the GitOps reconciler work on the first boot.
propagate_user_credentials() {
  section "Propagating credentials to ${USER_NAME}"

  if [[ "$USER_NAME" == "$(whoami)" ]]; then
    log "Install ran as ${USER_NAME} — credentials already in place"
    return
  fi

  local target_home="/home/${USER_NAME}"
  if ! id "$USER_NAME" >/dev/null 2>&1 || [[ ! -d "$target_home" ]]; then
    warn "User ${USER_NAME} has no home at ${target_home} — skipping"
    return
  fi

  local group
  group="$(id -gn "$USER_NAME" 2>/dev/null || echo users)"

  local age_key="$HOME/.config/sops/age/keys.txt"
  if [[ -f "$age_key" ]]; then
    if sudo install -Dm0600 -o "$USER_NAME" -g "$group" \
      "$age_key" "${target_home}/.config/sops/age/keys.txt"; then
      log "Age key copied to ${target_home}/.config/sops/age/keys.txt"
    else
      warn "Failed to copy the age key to ${USER_NAME}"
    fi
  fi

  if [[ -f "$SSH_KEY" ]]; then
    local key_name
    key_name="$(basename "$SSH_KEY")"
    sudo install -d -m0700 -o "$USER_NAME" -g "$group" "${target_home}/.ssh"
    sudo install -m0600 -o "$USER_NAME" -g "$group" "$SSH_KEY" "${target_home}/.ssh/${key_name}"
    if [[ -f "${SSH_KEY}.pub" ]]; then
      sudo install -m0644 -o "$USER_NAME" -g "$group" \
        "${SSH_KEY}.pub" "${target_home}/.ssh/${key_name}.pub"
    fi
    if [[ -f "$KNOWN_HOSTS" ]]; then
      sudo install -m0600 -o "$USER_NAME" -g "$group" \
        "$KNOWN_HOSTS" "${target_home}/.ssh/known_hosts"
    fi
    if [[ -f "$SSH_DIR/config" ]]; then
      # The managed block points at the operator's key path; rewrite it so the
      # target user's config references the copy in their own home.
      sudo install -m0600 -o "$USER_NAME" -g "$group" \
        "$SSH_DIR/config" "${target_home}/.ssh/config"
      sudo sed -i "s|${SSH_KEY}|${target_home}/.ssh/${key_name}|g" "${target_home}/.ssh/config"
    fi
    log "SSH key, known_hosts, and client config copied to ${USER_NAME}"
  fi
}

# ── Step: Validate SOPS secrets ─────────────────────────────────────────────
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

# ── Step: Verify the SSH daemon ─────────────────────────────────────────────
verify_ssh_daemon() {
  section "Verifying the SSH daemon"

  case ",${FEATURES}," in
    *,no-ssh,*) note "SSH feature disabled for this host — nothing to verify"; return ;;
  esac

  if systemctl is-active --quiet sshd.service || systemctl is-active --quiet sshd.socket; then
    log "sshd is active"
  else
    warn "sshd is not active — check: systemctl status sshd"
  fi

  if command -v ss >/dev/null 2>&1; then
    if ss -H -tln | awk '{print $4}' | grep -qE ':22$'; then
      log "sshd is listening on port 22"
    else
      warn "Nothing is listening on port 22"
    fi
  fi

  # NixOS materialises users.users.<name>.openssh.authorizedKeys.keys here.
  local akd="/etc/ssh/authorized_keys.d/${USER_NAME}"
  if sudo test -s "$akd" 2>/dev/null; then
    log "Authorized keys installed: ${akd} ($(sudo wc -l "$akd" | awk '{print $1}') key(s))"
  else
    warn "No authorized keys for ${USER_NAME} — inbound SSH will reject every key"
    warn "Add the key to sshAuthorizedKeys in hosts/${HOST}.nix and rebuild"
  fi

  local hk
  for hk in /etc/ssh/ssh_host_*_key.pub; do
    [[ -f "$hk" ]] || continue
    note "host key $(ssh-keygen -lf "$hk" 2>/dev/null || echo "$hk")"
  done

  # The daemon module opens port 22 on tailscale0 only (ivali.ssh.tailscaleOnly).
  note "Port 22 is reachable over the tailnet only (ivali.ssh.tailscaleOnly = true)"
  note "Reach this host with: ssh ${USER_NAME}@${HOST}.${TAILNET_DOMAIN}"
}

# ── Step: Verify the installed configuration ────────────────────────────────
verify_system() {
  section "Verifying the installed configuration"

  local current
  current=$(readlink -f /run/current-system 2>/dev/null || echo "")
  if [[ -n "$BUILT_TOPLEVEL" && "$current" == "$(readlink -f "$BUILT_TOPLEVEL" 2>/dev/null)" ]]; then
    log "Running the configuration just built"
  elif [[ -n "$BUILT_TOPLEVEL" ]]; then
    warn "Running system differs from the built closure — a reboot may be pending"
    note "built:   ${BUILT_TOPLEVEL}"
    note "current: ${current}"
  fi

  if [[ "$(hostname -s 2>/dev/null)" == "$HOST" ]]; then
    log "Hostname is ${HOST}"
  else
    note "Hostname becomes ${HOST} after reboot (currently $(hostname -s 2>/dev/null))"
  fi

  if command -v ivali >/dev/null 2>&1; then
    log "Control plane installed: $(command -v ivali)"
  else
    warn "ivali CLI not on PATH — open a new shell, or check the system package set"
  fi

  local hm_unit="home-manager-${USER_NAME}.service"
  if systemctl list-unit-files "$hm_unit" >/dev/null 2>&1; then
    local hm_state
    hm_state="$(systemctl show -p Result --value "$hm_unit" 2>/dev/null || echo unknown)"
    if [[ "$hm_state" == "success" ]]; then
      log "Home Manager generation activated for ${USER_NAME}"
    else
      warn "Home Manager activation result: ${hm_state} (journalctl -u ${hm_unit})"
    fi
  fi

  local failed
  failed="$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"
  if [[ -n "${failed// /}" ]]; then
    warn "Failed units: ${failed}"
  else
    log "No failed systemd units"
  fi

  if command -v tailscale >/dev/null 2>&1; then
    if tailscale status >/dev/null 2>&1; then
      log "Tailscale is up"
    else
      note "Tailscale not connected yet — run: sudo tailscale up --ssh"
    fi
  fi
}

# ── Step: Commit the generated host files ───────────────────────────────────
commit_host_files() {
  section "Committing the generated host files"

  if [[ -z "$(git -C "$REPO_DIR" diff --cached --name-only)" ]]; then
    note "Nothing staged — skipping commit"
    return
  fi

  local -a author=()
  if [[ -z "$(git -C "$REPO_DIR" config --get user.email || true)" ]]; then
    author=(-c "user.name=Willis Ivali" -c "user.email=${SSH_EMAIL}")
    note "No git identity configured — committing as Willis Ivali <${SSH_EMAIL}>"
  fi

  if git -C "$REPO_DIR" "${author[@]+"${author[@]}"}" commit -m "chore(hosts): add host configuration for ${HOST}" >/dev/null; then
    log "Committed: $(git -C "$REPO_DIR" log -1 --oneline)"
    note "Push when ready: git -C ${REPO_DIR} push origin ${BRANCH}"
  else
    warn "git commit failed — commit the staged files manually"
  fi
}

# ── Step: Optimize BTRFS (single NVMe) ──────────────────────────────────────
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

# ── Post-install ─────────────────────────────────────────────────────────────
post_install() {
  printf '\n%s╔══════════════════════════════════════════════════════════╗%s\n' "${C_GREEN}${C_BOLD}" "${C_RESET}"
  printf '%s║%s  ✓ Install complete                                       %s║%s\n' "${C_GREEN}${C_BOLD}" "${C_RESET}" "${C_GREEN}${C_BOLD}" "${C_RESET}"
  printf '%s╚══════════════════════════════════════════════════════════╝%s\n\n' "${C_GREEN}${C_BOLD}" "${C_RESET}"

  printf '  %sHost%s     %s\n'    "${C_DIM}" "${C_RESET}" "$HOST"
  printf '  %sUser%s     %s\n'    "${C_DIM}" "${C_RESET}" "$USER_NAME"
  printf '  %sDesktop%s  %s\n'    "${C_DIM}" "${C_RESET}" "$DESKTOP"
  printf '  %sRepo%s     %s\n'    "${C_DIM}" "${C_RESET}" "$REPO_DIR"
  printf '  %sSSH key%s  %s\n'    "${C_DIM}" "${C_RESET}" "$SSH_KEY"
  [[ -n "$LOG_FILE" ]] && printf '  %sLog%s      %s\n' "${C_DIM}" "${C_RESET}" "$LOG_FILE"
  printf '\n'

  if [[ "$MODE" == "fresh" ]]; then
    warn "══════════════════════════════════════════════════════════════"
    warn "FRESH MODE: Remember to re-encrypt secrets from your old machine:"
    warn "  1. Add this host's public key to .sops.yaml (already done)"
    warn "  2. From old machine: sops -e -i secrets/*.yaml"
    warn "  3. Push changes, then rebuild on this machine"
    warn "  4. Enable secrets in host spec: secrets = true"
    warn "══════════════════════════════════════════════════════════════"
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
       nautilus --version        # file manager
       super + enter             # launch the terminal
       super + b                 # launch the browser

  5. Test SSH, outbound and inbound:
       ssh -T git@gitlab.com                      # forge access
       ssh -T git@github.com                      # forge access
       ssh ${USER_NAME}@${HOST}.${TAILNET_DOMAIN}   # inbound over the tailnet

  6. Verify formatting and architecture before first commit:
       cd "$REPO_DIR"
       nix fmt                                        # format all .nix files
       go build -o /tmp/check-architecture-bin ./cmd/check-architecture/
       /tmp/check-architecture-bin                    # architecture lint

  7. Rebuild after changes:
       make rebuild
       # or: ./scripts/rebuild.sh

  8. Commit and push (GitLab is the source of truth):
       cd "$REPO_DIR"
       git status                                     # host files are staged
       git commit -m "chore(hosts): add host configuration for $HOST"
       git push origin ${BRANCH}

  9. Use the ivali CLI for ongoing management:
       ivali status           # system overview
       ivali deploy           # guided deployment flow
       ivali bootstrap host   # add another host

EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  start_logging
  banner

  # The step plan drives both execution order and the [nn/NN] counter, so the
  # progress numbers stay honest when optional phases are skipped.
  local -a plan=(
    require_nixos
    preflight_checks
    detect_identity
    enable_nix_features
    tune_nix_downloads
    install_tools
    setup_ssh_keys
    configure_ssh_client
    register_gitlab_ssh_key
    verify_forge_ssh
    clone_or_update_repo
    detect_hardware
    setup_age_key
  )
  [[ "$RE_ENCRYPT" == "true" ]] && plan+=(re_encrypt_secrets)
  plan+=(
    register_host
    stage_generated_files
    validate_registry_syntax
    install_format_hook
    validate_flake
    check_nix_format
    check_architecture
  )
  if [[ "$NO_REBUILD" != "true" ]]; then
    plan+=(build_system)
    if [[ "$BUILD_ONLY" != "true" ]]; then
      plan+=(
        switch_system
        propagate_user_credentials
        validate_sops
        verify_ssh_daemon
        verify_system
      )
    fi
  fi
  [[ "$COMMIT" == "true" ]] && plan+=(commit_host_files)
  [[ "$OPTIMIZE_BTRFS" == "true" ]] && plan+=(optimize_btrfs)

  TOTAL_STEPS=${#plan[@]}

  local step
  for step in "${plan[@]}"; do
    "$step"
  done

  if [[ "$NO_REBUILD" == "true" ]]; then
    note "Stopped before build/switch (--no-rebuild)"
  elif [[ "$BUILD_ONLY" == "true" ]]; then
    note "Built but not activated (--build-only). Activate with:"
    note "  sudo nixos-rebuild switch --flake ${REPO_DIR}#${HOST}"
  fi

  post_install
}

main "$@"
