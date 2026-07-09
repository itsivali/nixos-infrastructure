{ config, lib, pkgs, ... }:

let
  cfg = config.hydenix;
in
{
  imports = [
    ./display-manager.nix
    ./packages.nix
    ./audio.nix
  ];

  options.hydenix = {
    enable = lib.mkEnableOption "HyDE desktop environment (Hyprland)";
  };

  config = lib.mkIf cfg.enable {
    security.polkit.enable = true;

    services.gvfs.enable = true;
    services.udisks2.enable = true;
    services.accounts-daemon.enable = true;

    programs.dconf.enable = true;

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland
      ];
      configPackages = with pkgs; [ hyprland ];
      config.common.default = "hyprland";
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      GTK_USE_PORTAL = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
    };

    fonts.fontconfig = {
      enable = true;
      antialias = true;
      hinting.enable = true;
      hinting.style = "slight";
      subpixel.rgba = "rgb";
      subpixel.lcdfilter = "default";
    };

    services.upower.enable = true;

    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "lock";
      HandlePowerKey = "suspend";
      IdleAction = "ignore";
    };

    services.geoclue2.enable = lib.mkForce false;
    services.printing.enable = false;

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.bluetooth.enable = false;
    services.blueman.enable = false;
  };
}
