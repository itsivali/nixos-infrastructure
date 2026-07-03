#!/usr/bin/env bash
# lib/telegram.sh — Telegram Bot API helpers
#
# Dependencies: curl, jq
# Provides:     send_msg, send_long, send_photo, send_keyboard, send_inline_keyboard
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

# Send a message with "typing" action indicator.
# Usage: send_typing "$chat_id"
send_typing() {
  local chat="$1"
  curl -fsSL --max-time 5 -X POST "${API}/sendChatAction" \
    -d "chat_id=${chat}" \
    -d "action=typing" \
    > /dev/null 2>&1 || true
}

# Send a message with "upload_photo" action indicator.
# Usage: send_upload_photo "$chat_id"
send_upload_photo() {
  local chat="$1"
  curl -fsSL --max-time 5 -X POST "${API}/sendChatAction" \
    -d "chat_id=${chat}" \
    -d "action=upload_photo" \
    > /dev/null 2>&1 || true
}

# Send a message with "upload_document" action indicator.
# Usage: send_upload_document "$chat_id"
send_upload_document() {
  local chat="$1"
  curl -fsSL --max-time 5 -X POST "${API}/sendChatAction" \
    -d "chat_id=${chat}" \
    -d "action=upload_document" \
    > /dev/null 2>&1 || true
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

# Send a message with a persistent reply keyboard.
# Usage: send_keyboard "$chat_id" "message text" "button1" "button2" ...
send_keyboard() {
  local chat="$1" text="$2"
  shift 2
  local buttons=("$@")

  # Build the keyboard JSON: array of rows, each row is an array of buttons
  local keyboard='{"keyboard":['
  local first_row=true
  local i=0
  local row_size=3  # 3 buttons per row

  while (( i < ${#buttons[@]} )); do
    if [[ "$first_row" == true ]]; then
      first_row=false
    else
      keyboard+=','
    fi
    keyboard+='['
    local first_btn=true
    local row_end=$(( i + row_size ))
    (( row_end > ${#buttons[@]} )) && row_end=${#buttons[@]}

    for (( j=i; j<row_end; j++ )); do
      if [[ "$first_btn" == true ]]; then
        first_btn=false
      else
        keyboard+=','
      fi
      # Escape quotes in button text
      local btn="${buttons[$j]}"
      btn="${btn//\"/\\\"}"
      keyboard+="{\"text\":\"${btn}\"}"
    done
    keyboard+=']'
    i=$row_end
  done
  keyboard+='],\"resize_keyboard\":true,\"one_time_keyboard\":false}'

  local resp
  resp="$(curl -fsSL --max-time 10 -X POST "${API}/sendMessage" \
    -d "chat_id=${chat}" \
    --data-urlencode "text=${text}" \
    -d "parse_mode=Markdown" \
    -d "reply_markup=${keyboard}" 2>&1)"

  if [[ $? -eq 0 && "$resp" == *'"ok":true'* ]]; then
    return 0
  fi

  # Retry as plain text
  log "send_keyboard: Markdown failed for chat=${chat}, retrying plain text"
  curl -fsSL --max-time 10 -X POST "${API}/sendMessage" \
    -d "chat_id=${chat}" \
    --data-urlencode "text=${text}" \
    -d "reply_markup=${keyboard}" \
    > /dev/null 2>&1 || log "send_keyboard: plain text retry also failed for chat=${chat}"
}

# Send a message with inline keyboard buttons (callback queries).
# Usage: send_inline_keyboard "$chat_id" "message text" "btn1:callback1" "btn2:callback2"
send_inline_keyboard() {
  local chat="$1" text="$2"
  shift 2
  local buttons=("$@")

  # Build inline keyboard JSON
  local keyboard='{"inline_keyboard":['
  local first_row=true

  for btn_pair in "${buttons[@]}"; do
    local label="${btn_pair%%:*}"
    local callback="${btn_pair##*:}"

    if [[ "$first_row" == true ]]; then
      first_row=false
    else
      keyboard+=','
    fi
    keyboard+='[{'
    keyboard+="\"text\":\"${label}\","
    keyboard+="\"callback_data\":\"${callback}\""
    keyboard+='}]'
  done
  keyboard+=']}'

  local resp
  resp="$(curl -fsSL --max-time 10 -X POST "${API}/sendMessage" \
    -d "chat_id=${chat}" \
    --data-urlencode "text=${text}" \
    -d "parse_mode=Markdown" \
    -d "reply_markup=${keyboard}" 2>&1)"

  if [[ $? -eq 0 && "$resp" == *'"ok":true'* ]]; then
    # Return message ID for later editing
    echo "$resp" | jq -r '.result.message_id'
    return 0
  fi

  # Fallback to regular message
  send_msg "$chat" "$text"
  echo ""
}

# Edit an existing message's text and inline keyboard.
# Usage: edit_message "$chat_id" "$message_id" "new text" "btn1:cb1" "btn2:cb2"
edit_message() {
  local chat="$1" msg_id="$2" text="$3"
  shift 3
  local buttons=("$@")

  local keyboard=""
  if [[ ${#buttons[@]} -gt 0 ]]; then
    keyboard='{"inline_keyboard":['
    local first_row=true

    for btn_pair in "${buttons[@]}"; do
      local label="${btn_pair%%:*}"
      local callback="${btn_pair##*:}"

      if [[ "$first_row" == true ]]; then
        first_row=false
      else
        keyboard+=','
      fi
      keyboard+='[{'
      keyboard+="\"text\":\"${label}\","
      keyboard+="\"callback_data\":\"${callback}\""
      keyboard+='}]'
    done
    keyboard+=']}'
  fi

  local curl_args=(
    -fsSL --max-time 10
    -X POST "${API}/editMessageText"
    -d "chat_id=${chat}"
    -d "message_id=${msg_id}"
    --data-urlencode "text=${text}"
    -d "parse_mode=Markdown"
  )

  if [[ -n "$keyboard" ]]; then
    curl_args+=(-d "reply_markup=${keyboard}")
  fi

  curl "${curl_args[@]}" > /dev/null 2>&1 || log "edit_message: failed for chat=${chat} msg=${msg_id}"
}

# Answer a callback query (inline button press).
# Usage: answer_callback "$callback_query_id" "optional notification text"
answer_callback() {
  local callback_id="$1" text="${2:-}"
  local curl_args=(
    -fsSL --max-time 5
    -X POST "${API}/answerCallbackQuery"
    -d "callback_query_id=${callback_id}"
  )

  if [[ -n "$text" ]]; then
    curl_args+=(-d "text=${text}")
  fi

  curl "${curl_args[@]}" > /dev/null 2>&1 || true
}

# Hide the reply keyboard (send empty keyboard).
# Usage: hide_keyboard "$chat_id"
hide_keyboard() {
  local chat="$1"
  curl -fsSL --max-time 10 -X POST "${API}/sendMessage" \
    -d "chat_id=${chat}" \
    -d "text=Keyboard hidden." \
    -d 'reply_markup={"remove_keyboard":true}' \
    > /dev/null 2>&1 || true
}

# Send a progress indicator with dots animation.
# Usage: send_progress "$chat_id" "Loading"
send_progress() {
  local chat="$1" text="$2"
  local msg_id
  msg_id=$(send_msg "$chat" "${text}..." 2>/dev/null | jq -r '.result.message_id' 2>/dev/null || echo "")
  echo "$msg_id"
}

# Update a progress indicator.
# Usage: update_progress "$chat_id" "$message_id" "Loading (3/10)"
update_progress() {
  local chat="$1" msg_id="$2" text="$3"
  if [[ -n "$msg_id" ]]; then
    edit_message "$chat" "$msg_id" "${text}..."
  fi
}

# Format a number with commas (e.g., 1234567 -> 1,234,567).
# Usage: format_number "1234567"
format_number() {
  printf "%'d" "$1" 2>/dev/null || echo "$1"
}

# Format bytes to human readable (e.g., 1073741824 -> 1.0G).
# Usage: format_bytes "1073741824"
format_bytes() {
  local bytes=$1
  if [[ $bytes -ge 1073741824 ]]; then
    echo "$(awk "BEGIN{printf \"%.1f\", $bytes/1073741824}")G"
  elif [[ $bytes -ge 1048576 ]]; then
    echo "$(awk "BEGIN{printf \"%.1f\", $bytes/1048576}")M"
  elif [[ $bytes -ge 1024 ]]; then
    echo "$(awk "BEGIN{printf \"%.1f\", $bytes/1024}")K"
  else
    echo "${bytes}B"
  fi
}

# Format a timestamp to relative time (e.g., "2 hours ago").
# Usage: format_relative_time "1234567890"
format_relative_time() {
  local timestamp=$1
  local now
  now=$(date +%s)
  local diff=$(( now - timestamp ))

  if [[ $diff -lt 60 ]]; then
    echo "${diff}s ago"
  elif [[ $diff -lt 3600 ]]; then
    echo "$(( diff / 60 ))m ago"
  elif [[ $diff -lt 86400 ]]; then
    echo "$(( diff / 3600 ))h ago"
  else
    echo "$(( diff / 86400 ))d ago"
  fi
}
