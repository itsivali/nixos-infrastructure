##############################################################################
#
# Desktop — XFCE Session & Applications
#
# Purpose
# -------
# System-level XFCE desktop enablement: the XFCE session through the
# X11 display stack, LightDM login manager, the lightweight GTK application
# stack (Thunar, Ristretto, Mousepad, xarchiver, evince), XFCE power
# management, Bluetooth, and shared Linux desktop infrastructure.
#
# Ownership
# ---------
# ivali.desktop.xfce
#
# Responsibilities
# ----------------
# - Enable the XFCE desktop manager over the X11 display stack (LightDM)
# - Enable XFCE's own lightweight application set + window manager
# - Enable power management (upower + xfce4-power-manager for the laptop)
# - Enable Bluetooth explicitly (the GNOME module did it implicitly; XFCE does not)
# - Enable the GNOME Keyring secret service (PAM + dbus activation) so Wi-Fi
#   passwords and libsecret clients keep working
# - Theme Qt applications via QGnomePlatform (a GTK-based Qt theme, not a
#   GNOME Shell dependency) so LibreOffice/Electron follow the Gruvbox look
#
# Notes
# -----
# nixpkgs' XFCE module (services/desktop-managers/xfce.nix) already enables
# the core OS services and app stack: polkit_gnome, udisks2, accounts-daemon,
# gvfs, tumbler, xdg-desktop-portal (gtk + xapp), programs.thunar,
# programs.xfconf, libinput, colord, mousepad, ristretto, xfce4-terminal,
# xfce4-notifyd, xfce4-screenshooter, xfce4-appfinder, xfce4-session,
# xfce4-settings, xfce4-taskmanager and networkmanagerapplet/pavucontrol
# (when NetworkManager/PipeWire are enabled). Only the deltas are declared
# here.
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.xfce.enable or false) {
    # ── XFCE desktop manager over X11 (LightDM drivers this) ─────────────
    services.xserver.desktopManager.xfce.enable = true;
    services.xserver.enable = true;

    # Required by the Home Manager dconf module (home/theming.nix): without
    # it the dconf database service and GSettings plumbing are not declared,
    # so per-user dconf settings are not guaranteed to be served.
    programs.dconf.enable = true;

    # ── Power management (laptop) ────────────────────────────────────────
    # powerManagement.enable drives both xfce4-power-manager (installed by
    # the XFCE module) and services.upower (also tied to it): suspend on
    # battery, correct battery reporting, and the xfce power / display
    # dialog all depend on this.
    powerManagement.enable = true;

    # ── Bluetooth ────────────────────────────────────────────────────────
    # The GNOME desktop module enabled Bluetooth implicitly; XFCE does not.
    # Enable it explicitly so headphones, keyboards and mice work. The
    # WirePlumber Bluetooth codec configuration ships in desktop/common.
    hardware.bluetooth.enable = true;

    # ── GNOME Keyring (shared secret service) ────────────────────────────
    # Wi-Fi password storage (NetworkManager), libsecret clients and SSH key
    # storage depend on the freedesktop secret service. The XFCE module
    # enables it with mkDefault true; keep it enabled regardless.
    services.gnome.gnome-keyring.enable = true;

    # ── Qt theming through the GTK platform theme ────────────────────────
    # QGnomePlatform reads the active GTK settings (adw-gtk3-dark -> the
    # Gruvbox XFCE GTK theme) so the Qt apps (LibreOffice, Electron render
    # in Gruvbox style without any KDE dependency.
    qt.enable = true;
    qt.platformTheme = "gnome";
    qt.style = "adwaita-dark";

    environment.systemPackages = with pkgs; [
      # Lightweight XFCE-native archive manager (Xarchiver) + GTK PDF viewer
      # (Evince) — the missing default handlers for the XFCE MIME stack.
      xarchiver
      evince

      # Thumbnailers: webp/heic image loaders + video thumbnails (shared
      # with the previous GNOME stack; Thunar needs them too).
      webp-pixbuf-loader
      libheif
      ffmpegthumbnailer

      # Audio/mic test tooling shared with the audio diagnostic.
      pavucontrol

      # Bluetooth applet/manager for pairing in XFCE (no blueman dependency
      # in this build — blueberry requires mint's sessions; keep it simple).
      blueman
    ];

    # ── Restricted extras: exclude the handful of XFCE desktop daemons we
    #    deliberately do not run (paragraph + volumed are handled by the
    #    xfce4-notifyd and xfce4-pulseaudio-plugin equivalents).
    environment.xfce.excludePackages = with pkgs; [
      xfce4-volumed-pulse
    ];
  };
}
