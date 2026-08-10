##############################################################################
#
# Desktop — GNOME Session & Applications
#
# Purpose
# -------
# System-level GNOME desktop enablement: GNOME Shell session, GDM login
# manager, the curated GNOME/GTK application stack, GNOME Keyring secret
# service, and Qt theming through QGnomePlatform so the few Qt apps
# (e.g. LibreOffice) follow the GTK/Gruvbox look without any KDE dependency.
#
# Ownership
# ---------
# ivali.desktop.gnome
#
# Responsibilities
# ----------------
# - Enable the GNOME desktop manager + GDM (Wayland session, default)
# - Trim the stock GNOME app set to a curated, clutter-free selection
# - Provide archive, thumbnailer and "Open in Terminal" Nautilus integration
# - Enable the GNOME Keyring secret service (PAM + dbus activation)
# - Theme Qt applications via the GNOME platform theme (qt.platformTheme)
#
# Notes
# -----
# nixpkgs' GNOME module (services/desktop-managers/gnome.nix) already enables
# the core OS services, Shell and core apps (including the app stack that used
# to be listed here explicitly): polkit, power-profiles-daemon, Bluetooth,
# udisks2, gvfs, GNOME Online Accounts, xdg-desktop-portal (gnome + gtk),
# NetworkManager and the GNOME Keyring. Only the deltas are declared here.
#
# At this pinned nixpkgs rev the canonical option name is
# `services.desktopManager.gnome.enable`; the legacy
# `services.xserver.desktopManager.gnome.enable` is a renamed alias.
#
##############################################################################

{ config, lib, pkgs, self, ... }:

{
  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    # ── GNOME desktop manager + GDM (Wayland-only in GNOME 50) ──────────
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;
    services.displayManager.defaultSession = "gnome";

    # Required by the Home Manager dconf module (home/theming.nix): without
    # it the dconf database service and GSettings plumbing are not declared,
    # so per-user dconf settings are not guaranteed to be served.
    programs.dconf.enable = true;

    # Battery monitoring for the laptop (GNOME's module ties upower to
    # powerManagement.enable, which defaults to false — enable explicitly).
    services.upower.enable = true;

    # Trim the stock GNOME app set to a curated selection. Kept: Nautilus,
    # Loupe, Papers, GNOME Text Editor, Calculator, Characters, Logs,
    # System Monitor, Clocks, Calendar, Contacts-free shell, File Roller.
    # Removed: Epiphany browser, Maps, Music, Weather, Connections,
    # Contacts, Console (Kitty is the default terminal), Tour.
    environment.gnome.excludePackages = with pkgs; [
      epiphany
      gnome-tour
      gnome-maps
      gnome-music
      gnome-weather
      gnome-connections
      gnome-contacts
      gnome-console
    ];

    environment.systemPackages = with pkgs; [
      # Archive manager (Nautilus integration)
      file-roller

      # Nautilus "Open in Terminal" context-menu integration (-> kitty)
      nautilus-open-any-terminal

      # Thumbnailers: webp/heic image loaders + video thumbnails
      webp-pixbuf-loader
      libheif
      ffmpegthumbnailer

      # GSettings / dconf inspector for tweaking + troubleshooting
      dconf-editor

      # Gruvbox GNOME Shell theme (user-themes extension, see
      # home/gnome/extensions.nix). System-wide install puts it in
      # /run/current-system/sw/share/themes, which the extension searches.
      self.packages.${pkgs.stdenv.hostPlatform.system}.gnome-shell-gruvbox-theme
    ];

    # Qt integration through the GNOME platform theme: QGnomePlatform reads
    # the active GTK settings so Qt apps (LibreOffice, ...) render in
    # Gruvbox/GNOME style without any KDE package. adwaita-dark satisfies
    # the gnome-platform-theme style assertion (see qt.nix in nixpkgs).
    qt.enable = true;
    qt.platformTheme = "gnome";
    qt.style = "adwaita-dark";

    # GNOME Keyring secret service for Wi-Fi passwords (NetworkManager),
    # libsecret clients and SSH key storage. PAM integration is handled by
    # the GNOME session; this keeps the service enabled regardless.
    services.gnome.gnome-keyring.enable = true;
  };
}
