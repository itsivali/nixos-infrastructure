#!/usr/bin/env bash

set -euo pipefail

EMAIL="${1:-itsivali@outlook.com}"
KEY="$HOME/.ssh/id_ed25519"

echo "=========================================="
echo " GitLab SSH Key Generator"
echo "=========================================="
echo

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ -f "$KEY" ]]; then
    echo "✔ SSH key already exists:"
    echo "  $KEY"
else
    echo "Generating a new Ed25519 SSH key..."
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY"
    echo
    echo "✔ SSH key created."
fi

echo

# Start ssh-agent if necessary
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
    eval "$(ssh-agent -s)" >/dev/null
fi

ssh-add "$KEY" >/dev/null 2>&1 || true

echo
echo "=========================================="
echo "Public SSH Key"
echo "=========================================="
echo

cat "${KEY}.pub"

echo
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo
echo "1. Copy the key shown above."
echo "2. Open:"
echo "   https://gitlab.com/-/user_settings/ssh_keys"
echo "3. Click 'Add new key'."
echo "4. Paste the key."
echo "5. Give it a title (e.g. Laptop)."
echo "6. Save."

if command -v xdg-open >/dev/null; then
    xdg-open "https://gitlab.com/-/user_settings/ssh_keys" >/dev/null 2>&1 &
fi

echo
echo "To test your connection afterwards:"
echo
echo "ssh -T git@gitlab.com"
