#!/run/current-system/sw/bin/bash
# deployment-health.sh — system health gate
#
# Exits 0 (healthy) or 1 (unhealthy).
# Called by gitops-reconcile.sh and rollback.sh.
# Also runs on a 5-minute timer via deployment-health.service.
#
# Checks are ordered from cheapest/most critical to most expensive:
#   1. Internet connectivity
#   2. DNS resolution
#   3. GitLab reachability (needed for future pulls)
#   4. Tailscale (core infra)
#   5. Prometheus (optional — warn only, not fatal)
#   6. Grafana (optional — warn only, not fatal)

set -euo pipefail

PASS=0
FAIL=1

result=0

log()  { echo "[$(date -Iseconds)] $*"; }
ok()   { log "OK   : $1"; }
fail() { log "FAIL : $1"; result=1; }
warn() { log "WARN : $1"; }  # non-fatal

###########################################################################
# 1. Internet
###########################################################################

if ping -c 2 -W 3 1.1.1.1 > /dev/null 2>&1; then
  ok "Internet (ping 1.1.1.1)"
else
  fail "Internet down (ping 1.1.1.1 failed)"
fi

###########################################################################
# 2. DNS
###########################################################################

if dig gitlab.com +short +time=5 > /dev/null 2>&1; then
  ok "DNS (gitlab.com resolves)"
else
  fail "DNS failure (gitlab.com)"
fi

###########################################################################
# 3. GitLab reachability
###########################################################################

if curl -fsSL --max-time 10 https://gitlab.com > /dev/null 2>&1; then
  ok "GitLab reachable"
else
  fail "GitLab unreachable"
fi

###########################################################################
# 4. Tailscale (critical — needed for split DNS and VPN access)
###########################################################################

if systemctl is-active --quiet tailscaled; then
  ok "Tailscale running"
else
  fail "Tailscale (tailscaled) is not active"
fi

###########################################################################
# 5. Prometheus (warn only — may not be running on all profiles)
###########################################################################

if curl -fsSL --max-time 5 http://localhost:9090/-/healthy > /dev/null 2>&1; then
  ok "Prometheus healthy"
else
  warn "Prometheus not responding (localhost:9090) — non-fatal"
fi

###########################################################################
# 6. Grafana (warn only)
###########################################################################

if curl -fsSL --max-time 5 http://localhost:3000/api/health > /dev/null 2>&1; then
  ok "Grafana healthy"
else
  warn "Grafana not responding (localhost:3000) — non-fatal"
fi

###########################################################################
# Result
###########################################################################

if [[ "$result" -eq 0 ]]; then
  log "Health check PASSED"
else
  log "Health check FAILED — see above"
fi

exit "$result"
