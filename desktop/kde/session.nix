##############################################################################
#
# Desktop — KDE Plasma 6 Session & Applications
#
# Purpose
# -------
# System-level KDE Plasma 6 desktop enablement: the Plasma Wayland session
# via SDDM, the KDE application stack, KDE power management, Bluetooth,
# and the Mokka color schemes installed system-wide (for SDDM + login).
#
# Ownership
# ---------
# ivali.desktop.kde
#
# Responsibilities
# ----------------
# - Enable the KDE Plasma 6 desktop manager over Wayland
# - Enable SDDM as the display manager (Wayland-native greeter)
# - Enable power management (upower + power-profiles-daemon)
# - Enable Bluetooth explicitly
# - Enable native Qt theming (no QGnomePlatform needed under KDE)
# - Install Mokka KDE + Konsole color schemes system-wide so SDDM and
#   login greeters render in Mokka
#
# Notes
# -----
# nixpkgs' plasma6 module (services/desktop-managers/plasma6.nix) already
# enables the core KDE services: polkit-kde-agent, kwallet, gvfs,
# xdg-desktop-portal (kde backend), udisks2, sddm (when enabled), and the
# default KDE application set. Only the deltas are declared here.
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.kde.enable or false) {
    # ── KDE Plasma 6 desktop manager ─────────────────────────────────────
    services.desktopManager.plasma6.enable = true;
    services.xserver.enable = true;

    # Required for the Home Manager config modules and hardcoded settings.
    programs.dconf.enable = true;

    # ── SDDM display manager (Wayland greeter) ───────────────────────────
    # SDDM with the native Wayland backend. autoNumlock matches the GNOME
    # behavior; the breeze theme keeps the greeter minimal (Mokka theming
    # of the greeter itself is out of scope for this pass).
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;
      theme = "mokka";
    };

    # Boot straight into the KDE Plasma session.
    services.displayManager.defaultSession = "plasma";

    # ── Power management (laptop) ────────────────────────────────────────
    # powerManagement.enable drives upower; the Plasma power applet and
    # sleep/suspend behavior depend on it.
    powerManagement.enable = true;

    # Baseline CPU frequency governor. power-profiles-daemon (below) will
    # override this dynamically per profile, but schedutil is the correct
    # default for the AMD A6 APU.
    powerManagement.cpuFreqGovernor = "schedutil";

    # power-profiles-daemon provides balanced/performance/power-saver
    # profiles via D-Bus. Plasma exposes profile switching in the system
    # tray / settings.
    services.power-profiles-daemon.enable = true;

    # ── Bluetooth ────────────────────────────────────────────────────────
    # Enable Bluetooth explicitly so headphones, keyboards and mice work.
    # The WirePlumber Bluetooth codec configuration ships in desktop/common.
    hardware.bluetooth.enable = true;
    hardware.bluetooth.settings = {
      General = {
        AutoEnable = true;
      };
    };

    # ── Qt theming (native KDE) ──────────────────────────────────────────
    # Under KDE, Qt apps render natively via Breeze/Kvantum. No
    # QGnomePlatform/GTK platform theme needed.
    qt.enable = true;

    # ── Input / Touchpad ──────────────────────────────────────────────────
    services.libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        disableWhileTyping = true;
        scrollMethod = "twofinger";
      };
    };

    # ── Mokka color schemes + KDE application stack ──────────────────────
    environment.systemPackages = [
      # Mokka KDE color scheme (for SDDM + login greeters)
      (import ../../theme/mokka/kde-colorscheme.nix { inherit (pkgs) stdenv; })
      (import ../../theme/mokka/konsole-colorscheme.nix { inherit (pkgs) stdenv; })

      # Core KDE apps
      pkgs.kdePackages.konsole
      pkgs.kdePackages.dolphin
      pkgs.kdePackages.spectacle
      pkgs.kdePackages.ark
      pkgs.kdePackages.gwenview
      pkgs.kdePackages.okular

      # Firefox browser integration
      pkgs.kdePackages.plasma-browser-integration

      # Additional KDE tools
      pkgs.kdePackages.kcalc
      pkgs.kdePackages.yakuake

      # Thumbnailers: webp/heic image loaders
      pkgs.webp-pixbuf-loader
      pkgs.libheif
    ];

    # ── Exclude unnecessary KDE applications ─────────────────────────────
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      elisa
      kate
      konqueror
    ];
  };
}
