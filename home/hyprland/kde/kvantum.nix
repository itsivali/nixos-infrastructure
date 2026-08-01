##############################################################################
#
# Home — Kvantum Theme
#
# Purpose
# -------
# Declarative Gruvbox Kvantum theme: generates the theme .kvconfig
# ([GeneralColors] color overrides) from the theme engine, reuses KvArcDark's
# SVG geometry shipped with the Kvantum plugin, and selects the theme so every
# Qt application renders in Gruvbox. Paired with qt.style = "kvantum" (set in
# desktop/kde/default.nix).
#
# Ownership
# ---------
# home.hyprland.kde.kvantum, ivali.theme
#
# Responsibilities
# ----------------
# - Generate ~/.config/Kvantum/Gruvbox/Gruvbox.kvconfig
# - Deploy the theme SVG geometry (copy of KvArcDark.svg)
# - Point ~/.config/Kvantum/kvantum.kvconfig at the Gruvbox theme
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../themes;
  k = theme.kvantum;

  # [GeneralColors] overrides the colors baked into the SVG.
  generalColors = ''
    [%General]
    author=ivali
    comment=Gruvbox Dark (generated from the theme engine)
    gradient_sliders=false
    mirror_doc_tabs=true

    [GeneralColors]
    window.color=${k.window}
    base.color=${k.base}
    alt.base.color=${k.altBase}
    button.color=${k.button}
    light.color=${k.light}
    mid.light.color=${k.midLight}
    dark.color=${k.dark}
    mid.color=${k.mid}
    highlight.color=${k.highlight}
    inactive.highlight.color=${k.inactiveHighlight}
    text.color=${k.text}
    window.text.color=${k.windowText}
    button.text.color=${k.buttonText}
    disabled.text.color=${k.disabledText}
    tooltip.text.color=${k.tooltipText}
    highlight.text.color=${k.highlightedText}
    link.color=${k.link}
    link.visited.color=${k.linkVisited}
    progress.indicator.text.color=${k.progressText}
  '';
in
{
  home.file = {
    ".config/Kvantum/Gruvbox/Gruvbox.kvconfig".text = generalColors;

    # SVG geometry from KvArcDark, recolored by the kvconfig above.
    ".config/Kvantum/Gruvbox/Gruvbox.svg".source =
      "${pkgs.qt6Packages.qtstyleplugin-kvantum}/share/Kvantum/KvArcDark/KvArcDark.svg";

    # Theme selector — Kvantum loads ~/.config/Kvantum/<theme>/<theme>.kvconfig.
    ".config/Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=Gruvbox
    '';
  };
}
