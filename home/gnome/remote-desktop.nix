##############################################################################
#
# Home Manager — GNOME Remote Desktop
#
# Purpose
# -------
# Enable and configure the per-user GNOME Remote Desktop RDP backend. GRD
# generates its own TLS certificate and stores credentials in the GNOME
# keyring; no password or private key is stored in this repository.
#
# Ownership
# ---------
# dconf.settings."org/gnome/desktop/remote-desktop/rdp"
#
##############################################################################

{ lib, hostSpec, ... }:

let
  hostConfig = hostSpec.config or { };
  remoteDesktop = hostConfig.ivali.desktop.remote-desktop or {
    enable = false;
    port = 3389;
  };
  enabled = remoteDesktop.enable or false;
  port = remoteDesktop.port or 3389;
in
{
  dconf.settings = lib.mkIf enabled {
    "org/gnome/desktop/remote-desktop/rdp" = {
      enable = true;
      port = lib.gvariant.mkUint16 port;
      negotiate-port = false;
      screen-share-mode = "mirror-primary";
      view-only = false;
    };
  };
}
