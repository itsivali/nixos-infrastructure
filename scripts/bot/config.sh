# config.sh — Configuration constants for the bot control plane
#
# All configuration lives here. No business logic.
# Environment variables from systemd are exported before this file is sourced.
##############################################################################

# Secrets (read from SOPS-managed paths)
readonly BOT_TOKEN="${BOT_TOKEN:-$(cat /run/secrets/telegram_bot_token 2>/dev/null || true)}"
readonly CHAT_ID="${CHAT_ID:-$(cat /run/secrets/telegram_chat_id 2>/dev/null || true)}"
readonly GITLAB_TOKEN="${GITLAB_TOKEN:-$(cat /run/secrets/gitlab_token 2>/dev/null || true)}"

# Host identity
readonly HOST="${HOST_NAME:-$(hostname)}"
readonly DEFAULT_USER="${DEFAULT_USER:-ivali}"

# Paths
readonly REPO_DIR="${REPO_DIR:-/home/ivali/nixos-infrastructure}"
readonly STATE_DIR="/var/lib/ivali-bot"
readonly OFFSET_FILE="${STATE_DIR}/offset"
readonly APP_CACHE="${STATE_DIR}/app-cache.json"
readonly LAUNCH_LOG="/tmp/.ivali-bot-open.log"

# Telegram API
readonly API="https://api.telegram.org/bot${BOT_TOKEN}"
readonly MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-300}"

# GitLab API
readonly GITLAB_URL="${GITLAB_URL:-https://gitlab.com/willisivali/nixos-infrastructure}"
readonly GITLAB_API="${GITLAB_URL}/api/v4"
readonly GITLAB_PROJECT="willisivali%2Fnixos-infrastructure"

# Desktop discovery paths
readonly DESKTOP_DIRS=(
  /run/current-system/sw/share/applications
  /usr/share/applications
  "/home/${DEFAULT_USER}/.local/share/applications"
)

# Validate required secrets
if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
  echo "config.sh: missing telegram secrets (BOT_TOKEN or CHAT_ID)" >&2
  exit 1
fi
