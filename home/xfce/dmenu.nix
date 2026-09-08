##############################################################################
#
# Home — XFCE dmenu Launcher (Gruvbox)
#
# Purpose
# -------
# A Gruvbox-themed application launcher built on dmenu_run. The wrapper
# injects the Gruvbox Dark palette into dmenu so the fuzzy launcher matches
# the rest of the IVΛLI XFCE desktop instead of dmenu's stock black/white
# scheme. Every color comes from theme/gruvbox/colors.nix — nothing is
# hard-coded.
#
# Ownership
# ---------
# home.packages (dmenu-run wrapper)
#
# Responsibilities
# ----------------
# - Provide a `dmenu-run` binary that launches dmenu_run with the Gruvbox
#   palette, font, and prompt.
# - Keep the dmenu session-wide binary (dmenu_run) available for pipeline
#   usage while exposing the themed wrapper for bindings/scrips.
#
# Usage
# -----
# Bound to <Super>p in home/xfce/panel.nix; can also be run from a terminal
# with `dmenu-run`.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox;
  c = theme.colors;
in
{
  home.packages = with pkgs; [
    # dmenu-run wrapper (themed) — the previous home.packages dmenu entry
    # moves here so the themed launcher is the single dmenu surface.
    (pkgs.writeShellScriptBin "dmenu-run" ''
      exec ${pkgs.dmenu}/bin/dmenu_run \
        -fn "${theme.fonts.monospace}:size=${toString theme.fonts.size}" \
        -nb "${c.bg}" \
        -nf "${c.fg}" \
        -sb "${c.orange}" \
        -sf "${c.bgHard}" \
        -p "run:"
    '')
  ];
}
