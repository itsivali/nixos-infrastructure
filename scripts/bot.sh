#!/run/current-system/sw/bin/bash
# bot.sh — Redirect to v2 modular bot
#
# This file is kept for backward compatibility.
# The actual bot now lives at scripts/bot/bot.sh
#
exec "$(dirname "$0")/bot/bot.sh" "$@"
