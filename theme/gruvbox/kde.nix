##############################################################################
#
# Theme — Gruvbox KDE
#
# Purpose
# -------
# KDE Plasma color-scheme surface (.colors file). Widget role colors come
# from theme.qt.palette (the single Qt palette source); KDE-only surfaces
# (title bars, decorations, selection alternates) derive from the raw
# Gruvbox palette. Consumed by home/hyprland/krunner.
#
# Ownership
# ---------
# theme.gruvbox.kde
#
# Responsibilities
# ----------------
# - Map the Qt role palette onto KDE Colors:* groups
# - Render the final .colors file consumed by Plasma/Qt apps
#
##############################################################################

{ colors, palette }:

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
    Window = palette.window;
    WindowText = palette.windowText;
    ForegroundNormal = palette.text;
    ForegroundInactive = palette.placeholder;
    ForegroundLink = palette.link;
    ForegroundVisited = palette.linkVisited;
    DecorationFocus = palette.highlight;
    DecorationHover = colors.yellow;
    ActiveTitleBar = palette.button;
    InactiveTitleBar = palette.window;
    ActiveTitleBarText = palette.buttonText;
    InactiveTitleBarText = palette.placeholder;
    SelectionBackground = palette.highlight;
    SelectionAlternateBackground = colors.yellow;
    TooltipBackground = palette.toolTipBase;
    TooltipText = palette.toolTipText;
    BackgroundNormal = palette.window;
    BackgroundAlternate = palette.alternateBase;
  };

  view = {
    ViewBackground = palette.base;
    ViewText = palette.text;
    ForegroundNormal = palette.text;
    ForegroundInactive = palette.placeholder;
    ForegroundLink = palette.link;
    ForegroundVisited = palette.linkVisited;
    BackgroundNormal = palette.base;
    BackgroundAlternate = palette.alternateBase;
    SelectionBackground = palette.highlight;
    SelectionAlternateBackground = colors.yellow;
  };

  button = {
    ButtonBackground = palette.button;
    ButtonText = palette.buttonText;
    ForegroundNormal = palette.buttonText;
    ForegroundInactive = palette.placeholder;
    ForegroundLink = palette.link;
    ForegroundVisited = palette.linkVisited;
    BackgroundNormal = palette.button;
    BackgroundAlternate = palette.base;
    SelectionBackground = palette.highlight;
    SelectionAlternateBackground = colors.yellow;
  };

  selection = {
    SelectionBackground = palette.highlight;
    SelectionAlternateBackground = colors.yellow;
    SelectionText = palette.highlightedText;
    ForegroundNormal = palette.text;
    ForegroundInactive = palette.placeholder;
    ForegroundLink = palette.link;
    ForegroundVisited = palette.linkVisited;
    BackgroundNormal = palette.window;
    BackgroundAlternate = palette.alternateBase;
  };

  tooltip = {
    TooltipBackground = palette.toolTipBase;
    TooltipText = palette.toolTipText;
    ForegroundNormal = palette.toolTipText;
    ForegroundInactive = palette.placeholder;
    ForegroundLink = palette.link;
    ForegroundVisited = palette.linkVisited;
    BackgroundNormal = palette.toolTipBase;
    BackgroundAlternate = palette.base;
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
