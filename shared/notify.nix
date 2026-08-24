# Shared notification script (msmtp-based email).
# Used by observability/lite.nix and automation/recovery services.
# Import as: import ../shared/notify.nix { inherit pkgs; }
{ pkgs }:

pkgs.writeShellScriptBin "notify" (builtins.readFile ../scripts/notify.sh)
