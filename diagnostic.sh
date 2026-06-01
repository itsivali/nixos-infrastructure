#!/usr/bin/env bash
set -euo pipefail

echo "==> Creating backups"

ts=$(date +%s)

cp networking/default.nix networking/default.nix.bak.$ts
cp desktop/gnome-lean.nix desktop/gnome-lean.nix.bak.$ts

echo "==> Fixing services.resolved option renames"

perl -0pi -e '
s/fallbackDns\s*=\s*[(.*?)];//sg;
s/dnssec\s*=\s*"([^"]+)";//sg;
' networking/default.nix

perl -0pi -e '
s/Resolve\s*=\s*{/Resolve = {\n      FallbackDNS = [\n        "1.1.1.1"\n        "9.9.9.9"\n        "8.8.8.8"\n      ];\n\n      DNSSEC = "allow-downgrade";/s;
' networking/default.nix

echo "==> Fixing services.logind option renames"

perl -0pi -e '
s/services.logind\s*=\s*{\s*
\s*lidSwitch\s*=\s*"suspend";\s*
\s*lidSwitchExternalPower\s*=\s*"lock";\s*
\s*
\s*settings.Login\s*=\s*{\s*
\s*HandlePowerKey\s*=\s*"suspend";\s*
\s*IdleAction\s*=\s*"suspend";\s*
\s*IdleActionSec\s*=\s*"30min";\s*
\s*};\s*
\s*};/services.logind.settings.Login = {\n    HandleLidSwitch = "suspend";\n    HandleLidSwitchExternalPower = "lock";\n\n    HandlePowerKey = "suspend";\n    IdleAction = "suspend";\n    IdleActionSec = "30min";\n  };/sx;
' desktop/gnome-lean.nix

echo "==> Formatting"

if command -v nix >/dev/null 2>&1; then
nix fmt || true
fi

echo
echo "==> Checking for remaining deprecated options"

grep -R -n "fallbackDns" . || true
grep -R -n "dnssec =" . || true
grep -R -n "lidSwitch =" . || true
grep -R -n "lidSwitchExternalPower =" . || true

echo
echo "==> Done"
echo
echo "Next:"
echo "  nix eval .#nixosConfigurations.prague.config.system.build.toplevel.drvPath"
echo
echo "If evaluation succeeds:"
echo "  nix build .#nixosConfigurations.prague.config.system.build.toplevel"

