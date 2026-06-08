#!/usr/bin/env bash
set -euo pipefail

MESSAGE="${1:-No message}"

TOKEN_FILE="/run/secrets/telegram_bot_token"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "Telegram token missing"
  exit 0
fi

TOKEN="$(cat $TOKEN_FILE)"
CHAT_ID="7724444807"

curl -s -X POST \
  "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d text="${MESSAGE}" \
  -d parse_mode="Markdown" >/dev/null || true
