#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAIL: $1"
  exit 1
}

ping -c 2 1.1.1.1 >/dev/null || fail "Internet down"

dig gitlab.com +short >/dev/null || fail "DNS failure"

curl -fs https://gitlab.com >/dev/null || fail "GitLab unreachable"

systemctl is-active tailscaled >/dev/null || fail "Tailscale down"

curl -fs http://localhost:9090/-/healthy >/dev/null || fail "Prometheus down"

curl -fs http://localhost:3000/api/health >/dev/null || fail "Grafana down"

echo "OK"
