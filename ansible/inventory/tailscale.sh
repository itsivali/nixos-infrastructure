#!/run/current-system/sw/bin/bash
# tailscale.sh — dynamic Ansible inventory from Tailscale
#
# Usage: Set ANSIBLE_INVENTORY=tailscale.sh or use -i tailscale.sh
# Outputs JSON inventory from `tailscale status --json`.
# Supports --list and --host <hostname> modes.

set -euo pipefail

HOSTS_JSON=$(tailscale status --json 2>/dev/null || echo '{"Peer":{},"Self":{}}')

if [ "${1:-}" = "--list" ]; then
  # Output group with all Tailscale hosts
  PEERS=$(echo "$HOSTS_JSON" | jq -r '.Peer // {} | keys[]' 2>/dev/null || true)
  SELF_HOST=$(echo "$HOSTS_JSON" | jq -r '.Self.HostName // empty' 2>/dev/null || echo "")

  HOSTS="[]"
  for PEER in $PEERS; do
    HOSTNAME=$(echo "$HOSTS_JSON" | jq -r ".Peer[\"$PEER\"].HostName // \"$PEER\"" 2>/dev/null)
    IP=$(echo "$HOSTS_JSON" | jq -r ".Peer[\"$PEER\"].TailscaleIPs[0] // empty" 2>/dev/null)
    ONLINE=$(echo "$HOSTS_JSON" | jq -r ".Peer[\"$PEER\"].Online // false" 2>/dev/null)
    OS=$(echo "$HOSTS_JSON" | jq -r ".Peer[\"$PEER\"].OS // \"unknown\"" 2>/dev/null)

    if [ "$ONLINE" = "true" ] && [ -n "$IP" ]; then
      HOSTS=$(echo "$HOSTS" | jq --arg h "$HOSTNAME" --arg ip "$IP" --arg os "$OS" \
        '. + [{"hostname": $h, "ip": $ip, "os": $os}]')
    fi
  done

  # Add self
  if [ -n "$SELF_HOST" ]; then
    SELF_IP=$(echo "$HOSTS_JSON" | jq -r '.Self.TailscaleIPs[0] // empty' 2>/dev/null || echo "127.0.0.1")
    SELF_OS=$(echo "$HOSTS_JSON" | jq -r '.Self.OS // "unknown"' 2>/dev/null || echo "unknown")
    HOSTS=$(echo "$HOSTS" | jq --arg h "$SELF_HOST" --arg ip "$SELF_IP" --arg os "$SELF_OS" \
      '. + [{"hostname": $h, "ip": $ip, "os": $os}]')
  fi

  # Build Ansible inventory JSON
  ALL_HOSTNAMES=$(echo "$HOSTS" | jq -r '.[].hostname')
  ALL_IPS=$(echo "$HOSTS" | jq -r '.[].ip')

  # Create vars mapping
  VARS="{}"
  MAP="["
  FIRST=true
  for i in $(seq 0 $(($(echo "$HOSTS" | jq length) - 1))); do
    H=$(echo "$HOSTS" | jq -r ".[$i].hostname")
    IP=$(echo "$HOSTS" | jq -r ".[$i].ip")
    OS=$(echo "$HOSTS" | jq -r ".[$i].os")
    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      MAP+=","
    fi
    MAP+="{\"$H\": {\"ansible_host\": \"$IP\", \"os\": \"$OS\"}}"
  done
  MAP+="]"

  jq -n --argjson hosts "$MAP" '{
    "_meta": {
      "hostvars": ($hosts | map({(. | keys[0]): .[. | keys[0]]}) | add // {})
    },
    "all": {
      "hosts": ($hosts | map(. | keys[0])),
      "vars": {}
    },
    "nixos": {
      "hosts": ($hosts | map(. | keys[0]))
    }
  }'

elif [ "${1:-}" = "--host" ]; then
  # Output hostvars for a specific host
  HOSTNAME="${2:-}"
  echo "$HOSTS_JSON" | jq --arg h "$HOSTNAME" '{
    "ansible_host": (
      .Peer[$h].TailscaleIPs[0] //
      (if .Self.HostName == $h then .Self.TailscaleIPs[0] else empty end) //
      "127.0.0.1"
    )
  }'

else
  echo "Usage: $0 --list | --host <hostname>" >&2
  exit 1
fi
