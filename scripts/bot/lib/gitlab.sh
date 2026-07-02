#!/usr/bin/env bash
# lib/gitlab.sh — GitLab API wrapper
#
# Dependencies: curl, jq
# Provides:     gitlab_api
##############################################################################

# Make a GitLab API request.
# Usage: result=$(gitlab_api "/projects/123/pipelines" "GET")
#        result=$(gitlab_api "/projects/123/pipeline" "POST" '{"ref":"main"}')
gitlab_api() {
  local endpoint="$1"
  local method="${2:-GET}"
  local body="${3:-}"
  local curl_args=(
    -fsSL --max-time 30
    -X "$method"
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}"
    -H "Content-Type: application/json"
  )
  if [[ -n "$body" ]]; then
    curl_args+=(-d "$body")
  fi
  curl "${curl_args[@]}" "${GITLAB_API}${endpoint}" 2>&1 || echo '{"error":"GitLab API request failed"}'
}
