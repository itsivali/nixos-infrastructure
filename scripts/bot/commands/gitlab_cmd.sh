#!/usr/bin/env bash
# commands/gitlab_cmd.sh — /gitlab status|pipelines|trigger|mr — GitLab operations
##############################################################################

_cmd_gitlab() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  require_gitlab "$chat" || return

  local subcmd="${args%% *}"
  local subargs="${args#* }"

  case "$subcmd" in
    status)
      send_msg "$chat" "📦 Fetching GitLab project info…"
      local proj out
      proj="$(gitlab_api "/projects/${GITLAB_PROJECT}")"
      local name default_branch
      name="$(echo "$proj" | jq -r '.name // "unknown"')"
      default_branch="$(echo "$proj" | jq -r '.default_branch // "unknown"')"
      out="📦 *GitLab — ${name}*
${sep}
📋 *Default branch:* \`${default_branch}\`
🔗 *URL:* ${GITLAB_URL}
${sep}
*Latest pipeline:*
\`\`\`"
      local pipe
      pipe="$(gitlab_api "/projects/${GITLAB_PROJECT}/pipelines?per_page=1")"
      out+="$(echo "$pipe" | jq -r '.[0] | "  #\(.id) [\(.status)] \(.ref) \(.commit.title // "")"' 2>/dev/null || echo '  no pipelines found')"
      out+="
\`\`\`"
      send_long "$chat" "$out"
      ;;
    pipelines)
      send_msg "$chat" "📦 Fetching recent pipelines…"
      local pipes out
      pipes="$(gitlab_api "/projects/${GITLAB_PROJECT}/pipelines?per_page=10")"
      out="📦 *Recent Pipelines*
${sep}
\`\`\`"
      out+="$(echo "$pipes" | jq -r '.[] | "#\(.id)  \(.status | ascii_upcase | .[0:12])  \(.ref)  \(.created_at | split("T")[0])"' 2>/dev/null || echo '  no pipelines found')"
      out+="
\`\`\`"
      send_long "$chat" "$out"
      ;;
    trigger)
      send_msg "$chat" "🚀 Triggering pipeline on *main*…"
      local result
      result="$(gitlab_api "/projects/${GITLAB_PROJECT}/pipeline" "POST" '{"ref":"main"}' | jq -r '.id // empty' 2>/dev/null)"
      if [[ -n "$result" ]]; then
        send_msg "$chat" "✅ Pipeline *#${result}* triggered."
      else
        send_msg "$chat" "❌ Failed to trigger pipeline."
      fi
      ;;
    mr)
      send_msg "$chat" "📋 Fetching merge requests…"
      local mrs out
      mrs="$(gitlab_api "/projects/${GITLAB_PROJECT}/merge_requests?state=opened&per_page=10")"
      out="📋 *Open Merge Requests*
${sep}
\`\`\`"
      out+="$(echo "$mrs" | jq -r '.[] | "  !\(.iid)  \(.title[0:50])  ← \(.source_branch)"' 2>/dev/null || echo '  no open MRs')"
      out+="
\`\`\`"
      send_long "$chat" "$out"
      ;;
    *)
      send_msg "$chat" "📦 *GitLab Usage:*
\`/gitlab status\`     Project + latest pipeline
\`/gitlab pipelines\`  Recent pipelines
\`/gitlab trigger\`    Trigger a pipeline
\`/gitlab mr\`         List merge requests"
      ;;
  esac
}

register_command "gitlab" "_cmd_gitlab" "📦 GitLab pipelines & MRs"
