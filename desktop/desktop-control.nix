# desktop/desktop-control.nix
# GNOME Shell extension providing D-Bus API for remote desktop control.
#
# Packages the DesktopControl extension for GNOME Shell.
# Enablement (dconf) is handled by home-manager in home/environment/extensions.nix.

{ config, lib, pkgs, ... }:

let
  extUuid = "desktop-control@prague.ivali";
  extSrc = ./gnome-shell-extensions/desktop-control;

  desktopControlExtension = pkgs.stdenv.mkDerivation {
    name = "gnome-shell-extension-desktop-control";
    src = extSrc;
    installPhase = ''
      mkdir -p $out/share/gnome-shell/extensions/${extUuid}
      cp metadata.json $out/share/gnome-shell/extensions/${extUuid}/
      cp extension.js $out/share/gnome-shell/extensions/${extUuid}/
    '';
    meta = {
      description = "D-Bus API for remote desktop control via Telegram bot";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };
in
{
  config = lib.mkIf config.fleet.bot.enable {
    environment.systemPackages = [ desktopControlExtension ];
  };
}
