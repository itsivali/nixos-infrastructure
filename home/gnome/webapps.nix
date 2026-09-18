##############################################################################
#
# Home Manager — Microsoft 365 Web Apps (Edge PWA desktop entries)
#
# Purpose
# -------
# Pre-seeded Microsoft 365 web applications as standalone .desktop entries
# using Microsoft Edge in app mode. These appear in GNOME Search immediately
# and can be launched as standalone windows (no address bar, clean title bar).
#
# Edge's native PWA mechanism will refine these entries on first install:
# correct icons, window classes, and session persistence are handled by Edge
# when the user installs each PWA through the Edge UI (edge://apps).
#
# Ownership
# ---------
# xdg.desktopEntries
#
##############################################################################

{ lib, pkgs, ... }:

let
  # Microsoft 365 icon — shared across pre-seeded entries.
  # Edge's PWA install mechanism replaces this with application-specific icons
  # when the user installs each PWA through Edge.
  ms365Icon = pkgs.fetchurl {
    url = "https://teams.microsoft.com/favicon/prod/favicon-192x192.png";
    sha256 = "afcb5e1148c1af6438c5ad1a118a7d31e1ff119b70965a0576e766ad828c5f70";
  };

  # Edge app-mode launch helper.
  # Each entry opens a single URL in Edge's app mode (no address bar).
  # StartupWMClass separates each PWA in GNOME's task switcher.
  mkEdgePWA = name: url: wmClass: {
    inherit name;
    exec = "microsoft-edge --app=${url} --profile-directory=Default";
    icon = ms365Icon;
    terminal = false;
    type = "Application";
    categories = [ "GNOME" "Network" ];
    startupNotify = true;
    settings = {
      StartupWMClass = wmClass;
    };
  };
in
{
  xdg.desktopEntries = {
    "ms365-outlook" = mkEdgePWA
      "Outlook"
      "https://outlook.office.com"
      "microsoft-edge";

    "ms365-word" = mkEdgePWA
      "Word"
      "https://www.office.com/launch/word"
      "microsoft-edge";

    "ms365-excel" = mkEdgePWA
      "Excel"
      "https://www.office.com/launch/excel"
      "microsoft-edge";

    "ms365-powerpoint" = mkEdgePWA
      "PowerPoint"
      "https://www.office.com/launch/powerpoint"
      "microsoft-edge";

    "ms365-teams" = mkEdgePWA
      "Teams"
      "https://teams.microsoft.com"
      "microsoft-edge";

    "ms365-onedrive" = mkEdgePWA
      "OneDrive"
      "https://onedrive.live.com"
      "microsoft-edge";
  };
}
