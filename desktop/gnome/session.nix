##############################################################################
#
# Desktop — GNOME Session & Applications
#
# Purpose
# -------
# System-level GNOME desktop enablement: the GNOME Wayland session, the
# modern GNOME application stack, GNOME power management, Bluetooth, and
# shared Linux desktop infrastructure.
#
# Ownership
# ---------
# ivali.desktop.gnome
#
# Responsibilities
# ----------------
# - Enable the GNOME desktop manager over Wayland (GDM)
# - Enable the modern GNOME application stack (Nautilus, Evince, Console)
# - Enable power management (upower + power-profiles-daemon)
# - Enable Bluetooth explicitly
# - Enable the GNOME Keyring secret service (PAM + dbus activation)
# - Theme Qt applications via QGnomePlatform so LibreOffice/Electron
#   follow the Gruvbox look
#
# Notes
# -----
# nixpkgs' GNOME module (services/desktop-managers/gnome.nix) already enables
# the core OS services and app stack: polkit_gnome, udisks2, accounts-daemon,
# gvfs, xdg-desktop-portal (gnome backend), programs.dconf, nautilus, eog,
# evince, gnome-console, gnome-shell, gnome-settings-daemon, and
# networkmanagerapplet/pavucontrol (when NetworkManager/PipeWire are enabled).
# Only the deltas are declared here.
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    # ── GNOME desktop manager over Wayland (GDM drives this) ───────────
    services.desktopManager.gnome.enable = true;
    services.xserver.enable = true;

    # Required by the Home Manager dconf module (home/theming.nix): without
    # it the dconf database service and GSettings plumbing are not declared,
    # so per-user dconf settings are not guaranteed to be served.
    programs.dconf.enable = true;

    # ── Power management (laptop) ────────────────────────────────────────
    # powerManagement.enable drives upower and the GNOME power settings
    # dialog: suspend on battery, correct battery reporting, and the GNOME
    # power / display preferences all depend on this.
    powerManagement.enable = true;

    # Baseline CPU frequency governor. power-profiles-daemon (below) will
    # override this dynamically per profile, but schedutil is the correct
    # default for the AMD A6 APU.
    powerManagement.cpuFreqGovernor = "schedutil";

    # power-profiles-daemon provides balanced/performance/power-saver profiles
    # via D-Bus. GNOME Shell and applications can switch profiles through
    # the Quick Settings panel.
    services.power-profiles-daemon.enable = true;

    # ── Bluetooth ────────────────────────────────────────────────────────
    # Enable Bluetooth explicitly so headphones, keyboards and mice work.
    # The WirePlumber Bluetooth codec configuration ships in desktop/common.
    hardware.bluetooth.enable = true;

    # Auto-enable Bluetooth adapters at boot. Some Lenovo BIOSes leave the
    # btusb adapter soft-blocked via rfkill; BlueZ AutoEnable=true unblocks
    # it during daemon startup so pairing works without manual intervention.
    hardware.bluetooth.settings = {
      General = {
        AutoEnable = true;
      };
    };

    # ── GNOME Keyring (shared secret service) ────────────────────────────
    # Wi-Fi password storage (NetworkManager), libsecret clients and SSH key
    # storage depend on the freedesktop secret service.
    services.gnome.gnome-keyring.enable = true;

    # ── Qt theming through the GTK platform theme ────────────────────────
    # QGnomePlatform reads the active GTK settings (adw-gtk3-dark -> the
    # Gruvbox GTK theme) so Qt apps (LibreOffice, Electron) render in
    # Gruvbox style without any KDE dependency.
    qt.enable = true;
    qt.platformTheme = "gnome";
    qt.style = "adwaita-dark";

    # ── Input / Touchpad ──────────────────────────────────────────────────
    # libinput is the modern input stack. Pin the touchpad defaults here
    # so they persist across GNOME Settings changes.
    services.libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        disableWhileTyping = true;
        scrollMethod = "twofinger";
      };
    };

    environment.systemPackages = with pkgs; [
      # PDF viewer (also pulled by gnome core, but explicit for clarity)
      evince

      # Audio/mic test tooling shared with the audio diagnostic.
      pavucontrol

      # Thumbnailers: webp/heic image loaders + video thumbnails
      webp-pixbuf-loader
      libheif
      ffmpegthumbnailer

      # Advanced GNOME settings (fonts, themes, extensions)
      gnome-tweaks
    ];

    # ── Exclude unnecessary GNOME applications ─────────────────────────
    # Keep the core experience lean: shell, settings, files, console,
    # evince, eog, text editor. Remove apps that add weight without value.
    environment.gnome.excludePackages = with pkgs; [
      gnome-music
      gnome-contacts
      gnome-calendar
      gnome-characters
      gnome-font-viewer
      gnome-logs
      gnome-maps
      gnome-weather
      gnome-clocks
      gnome-calculator
      totem
      rhythmbox
      cheese
      epiphany
      sound-juicer
      gnome-connections
      simple-scan
      orca
      yelp
      gnome-tour
      gnome-user-docs
    ];
  };
}
