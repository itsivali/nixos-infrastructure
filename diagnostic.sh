#!/usr/bin/env bash
set -euo pipefail

FILE="desktop/gnome-lean.nix"

echo "==> Backing up ${FILE}"
cp "$FILE" "${FILE}.bak.$(date +%s)"

echo "==> Removing deprecated GDM Wayland option"

sed -i '/^[[:space:]]*wayland = true;$/d' "$FILE"

echo "==> Replacing services.logind.extraConfig"

python3 <<'PY'
from pathlib import Path
import re

f = Path("desktop/gnome-lean.nix")
text = f.read_text()

pattern = r"""extraConfig\s*=\s*''
\s*HandlePowerKey=suspend
\s*IdleAction=suspend
\s*IdleActionSec=30min
\s*'';"""

replacement = """settings.Login = {
      HandlePowerKey = "suspend";
      IdleAction = "suspend";
      IdleActionSec = "30min";
    };"""

text = re.sub(pattern, replacement, text, flags=re.MULTILINE)

f.write_text(text)
PY

echo
echo "==> Result"

grep -n -A12 -B4 "services.logind" "$FILE"

echo
echo "==> Testing evaluation"

nix eval .#nixosConfigurations.prague.config.system.build.toplevel.drvPath

echo
echo "Migration complete."
