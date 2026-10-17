#!/usr/bin/env bash
{
  echo "=== HOST ==="
  hostnamectl
  echo
  echo "=== NIXOS ==="
  nixos-version
  echo
  echo "=== DESKTOP ==="
  echo "Session: ${XDG_SESSION_TYPE:-unknown}"
  echo "Desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
  echo
  echo "=== RESOURCES ==="
  free -h
  uptime
  echo
  echo "=== TOP CPU PROCESSES ==="
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -15
  echo
  echo "=== RUNNING SERVICES ==="
  systemctl list-units --type=service --state=running --no-pager
  echo
  echo "=== NETWORKING ==="
  systemctl is-active NetworkManager 2>/dev/null || true
  systemctl is-active tailscaled 2>/dev/null || true
  echo
  echo "=== NIX CONFIGURATION ==="
  ls -la /etc/nixos
} 2>&1
