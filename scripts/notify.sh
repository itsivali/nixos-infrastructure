#!/run/current-system/sw/bin/bash
# notify.sh — send alert via Telegram and email
# Usage: notify.sh "message text"
#
# Reads from SOPS runtime secrets:
#   /run/secrets/telegram_bot_token
#   /run/secrets/telegram_chat_id
#   /run/secrets/notify_email
#
# Email is sent via msmtp (configure programs.msmtp in NixOS).
# Both channels are non-fatal — a broken email config won't abort the caller.

set -euo pipefail

MESSAGE="${1:-}"

if [[ -z "$MESSAGE" ]]; then
  echo "notify.sh: no message supplied" >&2
  exit 1
fi

HOST="$(hostname)"
TIMESTAMP="$(date -Iseconds)"
FULL_MSG="[${HOST}] ${TIMESTAMP}"$'\n'"${MESSAGE}"

###########################################################################
# Telegram
###########################################################################

send_telegram() {
  local token_file="/run/secrets/telegram_bot_token"
  local chat_file="/run/secrets/telegram_chat_id"

  if [[ ! -f "$token_file" || ! -f "$chat_file" ]]; then
    echo "notify.sh: telegram secrets missing" >&2
    return 0
  fi

  local token chat_id
  token="$(cat "$token_file")"
  chat_id="$(cat "$chat_file")"

  curl -fsSL \
    --max-time 10 \
    -X POST \
    "https://api.telegram.org/bot${token}/sendMessage" \
    -d "chat_id=${chat_id}" \
    --data-urlencode "text=${FULL_MSG}" \
    -d "parse_mode=Markdown" \
    > /dev/null \
  || echo "notify.sh: telegram send failed" >&2
}

###########################################################################
# Email via msmtp / sendmail
###########################################################################

send_email() {
  local email_file="/run/secrets/notify_email"

  if [[ ! -f "$email_file" ]]; then
    echo "notify.sh: notify_email secret missing" >&2
    return 0
  fi

  local to subject
  to="$(cat "$email_file")"
  subject="$(echo "${MESSAGE}" | head -1 | tr -d '\200-\377' | cut -c1-80)"

  {
    echo "To: ${to}"
    echo "From: gitops@${HOST}"
    echo "Subject: [GitOps/${HOST}] ${subject}"
    echo "Content-Type: text/plain; charset=utf-8"
    echo ""
    echo "${FULL_MSG}"
  } | sendmail -t || echo "notify.sh: email send failed" >&2
}

###########################################################################
# Fire both — failures are non-fatal to the caller
###########################################################################

send_telegram || true
send_email    || true
