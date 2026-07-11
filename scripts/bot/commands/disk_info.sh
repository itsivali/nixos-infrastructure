#!/usr/bin/env bash
# commands/disk_info.sh — /disk — dedicated disk information
##############################################################################

_cmd_disk() {
  local chat="$1" args="$2"
  local sep="━━━━━━━━━━━━━━━━━━━━━━"

  send_typing "$chat"

  # Filesystem usage
  local out="💾 *${HOST}* — Disk Information
${sep}

*Filesystems:*
\`\`\`"
  out+="$(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -E '(Filesystem|/dev/|tmpfs)' | head -10)"
  out+="
\`\`\`
"

  # Top directories by size
  out+="
*Large Directories:*
\`\`\`"
  out+="$(du -sh /home /nix /var /tmp /srv /etc 2>/dev/null | sort -rh | head -8)"
  out+="
\`\`\`
"

  # Inode usage
  out+="
*Inode Usage:*
\`\`\`"
  out+="$(df -i / 2>/dev/null | tail -1 | awk '{printf "Used: %s / %s (%s)\n", $3, $2, $5}')"
  out+="
\`\`\`
"

  # Disk I/O (if sysstat available)
  local io_output
  io_output=$(iostat -d -h 2>/dev/null | head -15 || echo "iostat not available")
  if [[ "$io_output" != "iostat not available" ]]; then
    out+="
*Disk I/O:*
\`\`\`
${io_output}
\`\`\`
"
  fi

  # Nix store
  local nix_size
  nix_size=$(du -sh /nix/store 2>/dev/null | cut -f1 || echo "unknown")
  out+="
*Nix Store:* ${nix_size}
"

  # Temp directory sizes
  local tmp_size
  tmp_size=$(du -sh /tmp 2>/dev/null | cut -f1 || echo "unknown")
  out+="*/tmp:* ${tmp_size}
"

  # Journal size
  local journal_size
  journal_size=$(journalctl --disk-usage 2>/dev/null | awk '{print $NF}' || echo "unknown")
  out+="*Journal:* ${journal_size}
"

  out+="
${sep}
_run \`/gc\` _to free space with garbage collection_"

  send_long "$chat" "$out"
}

register_command "disk" "_cmd_disk" "💾 Disk information"
