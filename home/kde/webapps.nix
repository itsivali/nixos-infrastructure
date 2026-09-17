##############################################################################
#
# Home Manager — Microsoft 365 Web Apps (Firefox PWAs)
#
# Purpose
# -------
# User-level Microsoft 365 web applications (M365, Word, Excel,
# PowerPoint) as standalone Firefox Progressive Web Apps via
# the firefoxpwa connector.
#
# Replaces the Edge --app mode desktop entries (home/webapps/edge-pwa.nix).
# Each PWA gets an isolated Firefox profile and a .desktop launcher.
#
# Ownership
# ---------
# programs.firefoxpwa
#
# Behavior
# --------
# After first login the user must install the Firefox PWA browser
# extension once (from addons.mozilla.org) and run:
#   firefoxpwa connector install
# The PWAs will then appear in the app launcher.
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  programs.firefoxpwa = {
    enable = true;

    # Shared profile for M365 apps (keeps M365 SSO session alive across apps)
    profiles."01H00000000000000000000000" = {
      name = "M365";

      sites = {
        "01H00000000000000000000001" = {
          name = "Microsoft 365";
          url = "https://www.office.com";
          manifestUrl = "https://www.office.com/manifest.json";
        };

        "01H00000000000000000000002" = {
          name = "Word Online";
          url = "https://word.office.com";
          manifestUrl = "https://word.office.com/manifest.json";
        };

        "01H00000000000000000000003" = {
          name = "Excel Online";
          url = "https://excel.office.com";
          manifestUrl = "https://excel.office.com/manifest.json";
        };

        "01H00000000000000000000004" = {
          name = "PowerPoint Online";
          url = "https://powerpoint.office.com";
          manifestUrl = "https://powerpoint.office.com/manifest.json";
        };
      };
    };
  };
}
