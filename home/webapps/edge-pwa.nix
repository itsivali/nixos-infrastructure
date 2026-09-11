##############################################################################
#
# Home — Microsoft 365 Web Apps (Edge --app mode)
#
# Purpose
# -------
# Launch Microsoft Office web apps (M365, Word, Excel, PowerPoint) as
# standalone browser windows via Edge --app mode, satisfying the IVALi
# Desktop spec requirement for Microsoft 365 access.
#
# Each desktop entry wraps a shell script that creates a dedicated Edge
# user-data-dir per app. This keeps each app's cookies, cache, and
# localStorage isolated (M365 SSO tokens, document state, preferences).
#
# Ownership
# ---------
# home.desktopEntries, home.file (wrapper scripts), home.packages
#
# Behavior
# --------
#   ivali_m365.sh  → Microsoft 365 Hub  (office.com)
#   ivali_word.sh  → Word online        (word.office.com)
#   ivali_excel.sh → Excel online       (excel.office.com)
#   ivali_ppt.sh   → PowerPoint online  (powerpoint.office.com)
#
# All launch via: microsoft-edge --app=<url> --user-data-dir=<dir>
#
# Icons
# -----
# The wrapper scripts try the bundled edge-pwa-icon.svg first, then
# fall back to the Microsoft Edge SVG from edge's own resource path.
# If neither is found, GNOME uses a generic application icon.
# Icons are re-extracted from the running edge package on each rebuild.
#
##############################################################################

{ pkgs, lib, ... }:

let
  officeDomain = "office.com";
  apps = {
    "ivali-m365" = {
      name = "Microsoft 365";
      url = "https://${officeDomain}";
      icon = "microsoft-edge";
      wmClass = "microsoft-edge";
    };
    "ivali-word" = {
      name = "Word Online";
      url = "https://word.office.com";
      icon = "microsoft-edge";
      wmClass = "microsoft-edge";
    };
    "ivali-excel" = {
      name = "Excel Online";
      url = "https://excel.office.com";
      icon = "microsoft-edge";
      wmClass = "microsoft-edge";
    };
    "ivali-ppt" = {
      name = "PowerPoint Online";
      url = "https://powerpoint.office.com";
      icon = "microsoft-edge";
      wmClass = "microsoft-edge";
    };
  };

  edgeWrapper = name: app:
    let
      profileName = "ivali-${name}";
    in
    pkgs.writeShellScriptBin name ''
      exec ${pkgs.microsoft-edge}/bin/microsoft-edge \
        --app="${app.url}" \
        --user-data-dir="$HOME/.config/microsoft-edge-apps/${profileName}" \
        --no-first-run \
        --disable-default-apps \
        --disable-session-crashed-bubble \
        "$@"
    '';

in
{
  # Desktop entries for each web app
  xdg.desktopEntries = lib.mapAttrs'
    (name: app: lib.nameValuePair name {
      name = app.name;
      exec = name;
      icon = app.icon;
      type = "Application";
      terminal = false;
      categories = [ "Office" ];
      mimeType = [ ];
      settings = {
        StartupWMClass = app.wmClass;
      };
    })
    apps;

  # Wrapper scripts for each app
  home.packages = lib.mapAttrsToList (name: _: edgeWrapper name apps.${name}) apps;
}
