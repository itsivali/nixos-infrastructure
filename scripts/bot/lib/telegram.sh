#!/usr/bin/env bash
# lib/telegram.sh — Telegram Bot API helpers
#
# Dependencies: curl, jq
# Provides:     send_msg, send_long, send_photo
##############################################################################

# Send a Markdown message. Falls back to plain text on parse failure.
# Usage: send_msg "$chat_id" "Hello *world*"
send_msg() {
  local chat="$1" text="$2"
  local resp
  resp="$(curl -fsSL --max-time 10 -X POST "${API}/sendMessage" \
    -d "chat_id=${chat}" \
    --data-urlencode "text=${text}" \
    -d "parse_mode=Markdown" \
    -d "disable_web_page_preview=true" 2>&1)"

  if [[ $? -eq 0 && "$resp" == *'"ok":true'* ]]; then
    return 0
  fi

  # Retry as plain text if Markdown fails
  log "send_msg: Markdown failed for chat=${chat}, retrying plain text"
  curl -fsSL --max-time 10 -X POST "${API}/sendMessage" \
    -d "chat_id=${chat}" \
    --data-urlencode "text=${text}" \
    -d "disable_web_page_preview=true" \
    > /dev/null 2>&1 || log "send_msg: plain text retry also failed for chat=${chat}"
}

# Flush the in-progress chunk buffer for send_long.
# Internal — relies on dynamic scoping from send_long's local variables.
_send_long_flush() {
  if [[ -n "$_sl_chunk" ]]; then
    local out="$_sl_chunk"
    if [[ "$_sl_in_code" -eq 1 ]]; then
      out+=$'\n```'
    fi
    send_msg "$_sl_chat" "$out"
  fi
  if [[ "$_sl_in_code" -eq 1 ]]; then
    _sl_chunk='```'
  else
    _sl_chunk=""
  fi
}

# Split a long message into Telegram-sized chunks on line boundaries.
# Preserves markdown code fences across chunk boundaries.
# Usage: send_long "$chat_id" "very long message" [max_chars]
send_long() {
  local _sl_chat="$1" msg="$2"
  local _sl_max="${3:-3500}"
  local _sl_chunk="" _sl_in_code=0
  local line piece candidate toggled

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Hard-split any single line exceeding chunk size
    while [[ ${#line} -gt $_sl_max ]]; do
      piece="${line:0:$_sl_max}"
      line="${line:$_sl_max}"
      if [[ -z "$_sl_chunk" ]]; then candidate="$piece"; else candidate="${_sl_chunk}"$'\n'"${piece}"; fi
      if [[ ${#candidate} -gt $_sl_max && -n "$_sl_chunk" ]]; then
        _send_long_flush
        if [[ -z "$_sl_chunk" ]]; then candidate="$piece"; else candidate="${_sl_chunk}"$'\n'"${piece}"; fi
      fi
      _sl_chunk="$candidate"
    done

    toggled=0
    [[ "$line" == '```'* ]] && toggled=1

    if [[ -z "$_sl_chunk" ]]; then candidate="$line"; else candidate="${_sl_chunk}"$'\n'"${line}"; fi

    if [[ ${#candidate} -gt $_sl_max && -n "$_sl_chunk" ]]; then
      _send_long_flush
      if [[ -z "$_sl_chunk" ]]; then candidate="$line"; else candidate="${_sl_chunk}"$'\n'"${line}"; fi
    fi
    _sl_chunk="$candidate"

    if [[ $toggled -eq 1 ]]; then
      _sl_in_code=$((1 - _sl_in_code))
    fi
  done <<< "$msg"

  if [[ -n "$_sl_chunk" ]]; then
    send_msg "$_sl_chat" "$_sl_chunk"
  fi
}

# Send a photo file to a Telegram chat.
# Usage: send_photo "$chat_id" "/tmp/screenshot.png" "optional caption"
send_photo() {
  local chat="$1" file="$2" caption="${3:-}"
  local curl_args=(
    -fsSL --max-time 30
    -X POST "${API}/sendPhoto"
    -F "chat_id=${chat}"
    -F "photo=@${file}"
  )
  if [[ -n "$caption" ]]; then
    curl_args+=(-F "caption=${caption}")
  fi
  curl "${curl_args[@]}" > /dev/null 2>&1 || log "send_photo: failed for chat=${chat}"
}
