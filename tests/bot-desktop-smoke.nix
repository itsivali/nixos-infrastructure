##############################################################################
#
# Bot Desktop Smoke Test
#
# Purpose
# -------
# Validate that the desktop-subsystem bridging layer works correctly.
# Runs the standalone test script and checks results.
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

let
  botScripts = ../scripts/bot;
  testScript = ./bot-desktop-smoke.sh;
in
pkgs.runCommand "bot-desktop-smoke"
{
  buildInputs = with pkgs; [ bash coreutils python3 shellcheck ];
} ''
  mkdir -p $out
  export BOT_SCRIPTS="${botScripts}"
  bash ${testScript} 2>&1 | tee "$out/test-output"
  if ! grep -q "RESULTS: 4 passed, 0 failed" "$out/test-output"; then
    echo "FAIL" > "$out/result"
    exit 1
  fi
  echo "PASS" > "$out/result"
''
