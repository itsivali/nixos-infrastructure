#!/usr/bin/env bash
set -euo pipefail

REPO="git@gitlab.com:willisivali/nixos-infrastructure.git"

echo "==> Verifying git repository"
git rev-parse --git-dir >/dev/null

echo "==> Switching origin to SSH"
git remote set-url origin "$REPO"

echo
echo "Current remotes:"
git remote -v

echo
echo "==> Updating .gitignore"

touch .gitignore

append_if_missing() {
    local pattern="$1"

    if ! grep -qxF "$pattern" .gitignore 2>/dev/null; then
        echo "$pattern" >> .gitignore
    fi
}

append_if_missing "*.bak.*"
append_if_missing "*.pre-repair"
append_if_missing "*.pre-grafana-fix"
append_if_missing "secrets/grafana-secret-key"
append_if_missing ".direnv/"
append_if_missing "result"

git add .gitignore

echo
echo "==> Removing tracked backup files"

git ls-files | grep -E '\.bak\.[0-9]+$' | while read -r f; do
    git rm --cached "$f"
done || true

echo
echo "==> Removing tracked repair artifacts"

git ls-files | grep -E '\.pre-repair$|\.pre-grafana-fix$' | while read -r f; do
    git rm --cached "$f"
done || true

echo
echo "==> Removing Grafana secret from Git tracking"

git rm --cached secrets/grafana-secret-key 2>/dev/null || true

echo
echo "==> Staging cleanup"
git add -A

echo
echo "==> Amending previous commit"
git commit --amend --no-edit

echo
echo "==> Testing SSH access"
ssh -T git@gitlab.com || true

echo
echo "==> Files that will be pushed"
git diff --name-only origin/main..HEAD 2>/dev/null || true

echo
echo "==> Latest commit"
git log --oneline -1

echo
read -rp "Push to GitLab now? [y/N] " ANSWER

if [[ "${ANSWER,,}" == "y" ]]; then
    git push --force-with-lease origin main
fi

echo
echo "Done."
