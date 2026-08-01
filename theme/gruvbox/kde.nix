##############################################################################
#
# Theme — Gruvbox KDE
#
# Purpose
# -------
# KDE Plasma color-scheme surface (.colors file) derived from the palette.
# Consumed by home/hyprland/krunner and any KDE application theming.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
##############################################################################

{ colors }:

let
  # KDE uses 8-bit hex (RRGGBB) in .colors files.
  hex = c: builtins.substring 1 7 c;

  schemeName = "Gruvbox Dark";
  schemeId = "GruvboxDark";
  fileName = "${schemeId}.colors";

  section = name: attrs:
    (builtins.concatStringsSep "\n" (
      [ "[${name}]" ]
      ++ map (k: "${k}=${hex attrs.${k}}") (builtins.attrNames attrs)
    ));

  window = {
    Window = colors.bg;
    WindowText = colors.fg;
    ForegroundNormal = colors.fg;
    ForegroundInactive = colors.gray;
    ForegroundLink = colors.blue;
    ForegroundVisited = colors.purple;
    DecorationFocus = colors.orange;
    DecorationHover = colors.yellow;
    ActiveTitleBar = colors.bg1;
    InactiveTitleBar = colors.bg;
    ActiveTitleBarText = colors.fg;
    InactiveTitleBarText = colors.gray;
    SelectionBackground = colors.orange;
    SelectionAlternateBackground = colors.yellow;
    TooltipBackground = colors.bg1;
    TooltipText = colors.fg;
    BackgroundNormal = colors.bg;
    BackgroundAlternate = colors.bg1;
  };

  view = {
    ViewBackground = colors.bg;
    ViewText = colors.fg;
    ForegroundNormal = colors.fg;
    ForegroundInactive = colors.gray;
    ForegroundLink = colors.blue;
    ForegroundVisited = colors.purple;
    BackgroundNormal = colors.bg;
    BackgroundAlternate = colors.bg1;
    SelectionBackground = colors.orange;
    SelectionAlternateBackground = colors.yellow;
  };

  button = {
    ButtonBackground = colors.bg1;
    ButtonText = colors.fg;
    ForegroundNormal = colors.fg;
    ForegroundInactive = colors.gray;
    ForegroundLink = colors.blue;
    ForegroundVisited = colors.purple;
    BackgroundNormal = colors.bg1;
    BackgroundAlternate = colors.bg;
    SelectionBackground = colors.orange;
    SelectionAlternateBackground = colors.yellow;
  };

  selection = {
    SelectionBackground = colors.orange;
    SelectionAlternateBackground = colors.yellow;
    SelectionText = colors.bgHard;
    ForegroundNormal = colors.fg;
    ForegroundInactive = colors.gray;
    ForegroundLink = colors.blue;
    ForegroundVisited = colors.purple;
    BackgroundNormal = colors.bg;
    BackgroundAlternate = colors.bg1;
  };

  tooltip = {
    TooltipBackground = colors.bg1;
    TooltipText = colors.fg;
    ForegroundNormal = colors.fg;
    ForegroundInactive = colors.gray;
    ForegroundLink = colors.blue;
    ForegroundVisited = colors.purple;
    BackgroundNormal = colors.bg1;
    BackgroundAlternate = colors.bg;
  };
in
{
  inherit schemeName schemeId fileName;

  # Rendered .colors file content.
  colorsFile = ''
    [General]
    ColorScheme=${schemeId}
    Name=${schemeName}

    ${section "Colors:Window" window}

    ${section "Colors:View" view}

    ${section "Colors:Button" button}

    ${section "Colors:Selection" selection}

    ${section "Colors:Tooltip" tooltip}
  '';
}
