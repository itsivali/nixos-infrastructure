#!/usr/bin/env bash
# commands/github_cmd.sh — /github status|actions|issues|prs — GitHub operations
##############################################################################

_cmd_github() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  local subcmd="${args%% *}"

  local gh_token="${GITHUB_TOKEN:-}"
  if [[ -z "$gh_token" ]]; then
    gh_token="$(cat /run/secrets/github_token 2>/dev/null || true)"
  fi

  if [[ -z "$gh_token" ]]; then
    send_msg "$chat" "❌ GitHub token not configured.
Set GITHUB_TOKEN or add github_token to SOPS secrets."
    return
  fi

  local repo="itsivali/nixos-infrastructure"
  local api="https://api.github.com"

  case "$subcmd" in
    status)
      send_msg "$chat" "🐙 Fetching GitHub repo info…"
      local repo_info
      repo_info="$(curl -s -H "Authorization: token ${gh_token}" \
        "${api}/repos/${repo}" 2>/dev/null)" || true
      local name stars forks default_branch
      name="$(echo "$repo_info" | jq -r '.full_name // "unknown"')"
      stars="$(echo "$repo_info" | jq -r '.stargazers_count // 0')"
      forks="$(echo "$repo_info" | jq -r '.forks_count // 0')"
      default_branch="$(echo "$repo_info" | jq -r '.default_branch // "unknown"')"

      out="🐙 *GitHub — ${name}*
${sep}
⭐ *Stars:* ${stars}  🍴 *Forks:* ${forks}
📋 *Default branch:* \`${default_branch}\`
🔗 *URL:* https://github.com/${repo}
${sep}
*Latest workflow run:*
\`\`\`"
      local runs
      runs="$(curl -s -H "Authorization: token ${gh_token}" \
        "${api}/repos/${repo}/actions/runs?per_page=1" 2>/dev/null)" || true
      out+="$(echo "$runs" | jq -r '.workflow_runs[0] | "  #\(.id) [\(.conclusion // .status)] \(.name) \(.head_branch)"' 2>/dev/null || echo '  no runs found')"
      out+="
\`\`\`"
      send_long "$chat" "$out"
      ;;
    actions|runs)
      send_msg "$chat" "🐙 Fetching recent workflow runs…"
      local runs
      runs="$(curl -s -H "Authorization: token ${gh_token}" \
        "${api}/repos/${repo}/actions/runs?per_page=10" 2>/dev/null)" || true
      out="🐙 *Recent Workflow Runs*
${sep}
\`\`\`"
      out+="$(echo "$runs" | jq -r '.workflow_runs[] | "#\(.id)  \(.conclusion // .status | ascii_upcase | .[0:12])  \(.name)  \(.created_at | split("T")[0])"' 2>/dev/null || echo '  no runs found')"
      out+="
\`\`\`"
      send_long "$chat" "$out"
      ;;
    issues)
      send_msg "$chat" "🐙 Fetching open issues…"
      local issues
      issues="$(curl -s -H "Authorization: token ${gh_token}" \
        "${api}/repos/${repo}/issues?state=open&per_page=10" 2>/dev/null)" || true
      out="🐙 *Open Issues*
${sep}
\`\`\`"
      out+="$(echo "$issues" | jq -r '.[] | select(.pull_request == null) | "  #\(.number)  \(.title[0:50])  [\(.labels | map(.name) | join(","))]"' 2>/dev/null || echo '  no open issues')"
      out+="
\`\`\`"
      send_long "$chat" "$out"
      ;;
    prs|pull)
      send_msg "$chat" "🐙 Fetching pull requests…"
      local prs
      prs="$(curl -s -H "Authorization: token ${gh_token}" \
        "${api}/repos/${repo}/pulls?state=open&per_page=10" 2>/dev/null)" || true
      out="🐙 *Open Pull Requests*
${sep}
\`\`\`"
      out+="$(echo "$prs" | jq -r '.[] | "  #\(.number)  \(.title[0:50])  ← \(.head.ref)"' 2>/dev/null || echo '  no open PRs')"
      out+="
\`\`\`"
      send_long "$chat" "$out"
      ;;
    *)
      send_msg "$chat" "🐙 *GitHub Usage:*
\`/github status\`     Repository + latest action
\`/github actions\`    Recent workflow runs
\`/github issues\`     Open issues
\`/github prs\`        Open pull requests"
      ;;
  esac
}

register_command "github" "_cmd_github" "🐙 GitHub repo & actions"
