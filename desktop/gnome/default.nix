{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  imports = [
    ./audio.nix
    ./packages.nix
  ];

  options.ivali.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment";
  };

  config = lib.mkIf cfg.enable {
    # GNOME desktop core
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;

    # GDM settings
    services.displayManager.gdm = {
      autoSuspend = false;
    };

    # DConf for extension persistence
    programs.dconf = {
      enable = true;
      profiles = {
        user = {
          databases = [
            {
              settings = {
                "org/gnome/shell" = {
                  disable-user-extensions = false;
                  enabled-extensions = [
                    "appindicatorsupport@rgcjonas.gmail.com"
                    "dash-to-dock@micxgx.gmail.com"
                    "blur-my-shell@aunetx"
                    "user-theme@gnome-shell-extensions.gcampax.github.com"
                    "caffeine@patapon.info"
                    "clipboard-indicator@tudmotu.com"
                    "Vitals@CoreCoding.com"
                    "sound-output-device-chooser@kgshank.net"
                  ];
                };
              };
            }
          ];
        };
      };
    };

    # Shell integration
    security.polkit.enable = true;
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    services.accounts-daemon.enable = true;
    services.upower.enable = true;

    # Session environment
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      GTK_USE_PORTAL = "1";
      XDG_CURRENT_DESKTOP = "GNOME";
      XDG_SESSION_DESKTOP = "gnome";
      XDG_SESSION_TYPE = "wayland";
    };

    # Fontconfig
    fonts.fontconfig = {
      enable = true;
      antialias = true;
      hinting.enable = true;
      hinting.style = "slight";
      subpixel.rgba = "rgb";
      subpixel.lcdfilter = "default";
    };

    # Power management
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "lock";
      HandlePowerKey = "suspend";
      IdleAction = "ignore";
    };

    # Hardware acceleration
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
