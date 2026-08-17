# Shared Telegram notification script.
# Used by observability/lite.nix and automation/bot-watchdog.nix.
# Import as: import ../shared/notify.nix { inherit pkgs; }
{ pkgs }:

pkgs.writeShellScriptBin "notify" (builtins.readFile ../scripts/notify.sh)
