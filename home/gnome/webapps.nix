##############################################################################
#
# Home Manager — Microsoft 365 Web Apps (GNOME .desktop entries)
#
# Purpose
# -------
# User-level Microsoft 365 web applications as standalone .desktop entries
# using Firefox --new-window. These appear in GNOME Search and can be
# launched as standalone windows (no address bar, clean title bar).
#
# Replaces the KDE firefoxpwa approach with native GNOME .desktop entries.
#
# Ownership
# ---------
# home.file, xdg.desktopEntries
#
##############################################################################

{ config, lib, ... }:

let
  # Firefox base command with --new-window for a native app feel.
  # Each entry opens a single URL; --class allows per-app icon/window grouping.
  mkWebApp = name: url: {
    name = name;
    exec = "firefox --class=${name} --new-window ${url}";
    icon = "firefox";
    terminal = false;
    type = "Application";
    categories = [ "GNOME" "Network" "WebBrowser" ];
    startupNotify = true;
  };
in
{
  xdg.desktopEntries = {
    "outlook" = mkWebApp "Outlook" "https://outlook.live.com";
    "word-online" = mkWebApp "WordOnline" "https://word.office.com";
    "excel-online" = mkWebApp "ExcelOnline" "https://excel.office.com";
    "powerpoint-online" = mkWebApp "PowerPointOnline" "https://powerpoint.office.com";
    "teams" = mkWebApp "Teams" "https://teams.microsoft.com";
    "onedrive" = mkWebApp "OneDrive" "https://onedrive.live.com";
  };
}
