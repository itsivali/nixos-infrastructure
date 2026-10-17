#!/run/current-system/sw/bin/bash
# gitops-deploy-decision.sh — unit test for the deploy decision in
# scripts/gitops-reconcile.sh
#
# The GitOps reconciler must NOT treat "checkout HEAD == origin" as proof of
# deployment: an interrupted or failed build leaves the pull applied but the
# running system un-updated, which wedges the loop forever (it logs
# "Already up-to-date" every cycle and never retries). The decision is instead
# based on the last *successfully deployed* revision.
#
# Usage: bash gitops-deploy-decision.sh <path-to-gitops-reconcile.sh>

set -euo pipefail

lib="${1:?usage: gitops-deploy-decision.sh <gitops-reconcile.sh>}"

# Avoid `hostname` during the sourced script's top-level config.
export HOST_NAME="gitops-deploy-decision"

# shellcheck source=/dev/null
source "$lib"

fail=0

# gitops_deploy_needed <local> <remote> <deployed>
# expected: "0" = deploy required, "1" = nothing to do
check() {
  local desc="$1" expected="$2"
  shift 2
  local rc=0
  gitops_deploy_needed "$@" && rc=0 || rc=1
  if [[ "$rc" == "$expected" ]]; then
    echo "ok   - ${desc}"
  else
    echo "FAIL - ${desc} (expected rc=${expected}, got rc=${rc})"
    fail=1
  fi
}

R="306b71679e97dbe0d87a9ec6f92e7d9401bc5e75"

echo "## gitops_deploy_needed"
check "checkout current and running system deployed -> skip" 1 "$R" "$R" "$R"
check "checkout current but build was interrupted -> deploy" 0 "$R" "$R" "9fd26ed0000000000000000000000000000000000"
check "no deploy marker recorded -> deploy" 0 "$R" "$R" ""
check "checkout behind remote -> deploy" 0 "9fd26ed0000000000000000000000000000000000" "$R" "$R"
check "empty remote -> deploy" 0 "$R" "" ""

echo "## gitops_deployed_sha"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf '{"state":"complete","commit_sha":"deadbeef"}' > "$tmp/last-deploy.json"
got="$(gitops_deployed_sha "$tmp/last-deploy.json")"
if [[ "$got" == "deadbeef" ]]; then
  echo "ok   - reads commit_sha from a complete deploy"
else
  echo "FAIL - expected deadbeef, got '${got}'"
  fail=1
fi

printf '{"state":"failed","commit_sha":"deadbeef"}' > "$tmp/last-deploy.json"
got="$(gitops_deployed_sha "$tmp/last-deploy.json")"
if [[ -z "$got" ]]; then
  echo "ok   - a failed deploy is not treated as deployed"
else
  echo "FAIL - failed deploy reported '${got}'"
  fail=1
fi

if [[ ! -f "$tmp/missing.json" ]]; then
  got="$(gitops_deployed_sha "$tmp/missing.json")"
  if [[ -z "$got" ]]; then
    echo "ok   - a missing marker yields nothing"
  else
    echo "FAIL - missing marker yielded '${got}'"
    fail=1
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
