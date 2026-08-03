##############################################################################
#
# Desktop — GNOME Applications
#
# Purpose
# -------
# GNOME application + service integration for the Hyprland desktop. This is
# the system-level counterpart to desktop/kde (now removed): it installs the
# GNOME/GTK application stack (Nautilus file manager, Loupe image viewer,
# Papers PDF viewer, File Roller archive manager, GNOME Text Editor, and the
# small GNOME utility set), enables the GNOME Keyring secret service, and
# configures Qt theming through QGnomePlatform so the few remaining Qt apps
# (e.g. LibreOffice) follow the GTK/Gruvbox look without any KDE dependency.
#
# Ownership
# ---------
# ivali.desktop.gnome
#
# Responsibilities
# ----------------
# - Install the GNOME application stack (system-wide)
# - Provide archive, thumbnail, and "Open in Terminal" Nautilus integration
# - Enable the GNOME Keyring secret service (PAM + dbus activation)
# - Theme Qt applications via the GNOME platform theme (qt.platformTheme)
#
# Usage
# -----
# Auto-discovered by desktop/default.nix; gated behind
# ivali.desktop.hyprland.enable (set in hosts/<name>.nix).
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.hyprland.enable or false) {
    # Required by the Home Manager dconf module (home/theming.nix): without
    # it the dconf database service and GSettings plumbing are not declared,
    # so per-user dconf settings (e.g. color-scheme) are not guaranteed to be
    # served to GNOME/GTK applications.
    programs.dconf.enable = true;

    environment.systemPackages = with pkgs; [
      # File manager + GTK application stack
      nautilus
      loupe
      papers
      file-roller
      gnome-text-editor

      # GNOME utilities (KDE replacements + desktop tools)
      gnome-calculator
      gnome-characters
      gnome-logs
      hyprpicker
      seahorse

      # Secret service (org.freedesktop.secrets)
      gnome-keyring

      # Nautilus "Open in Terminal" context-menu integration
      nautilus-open-any-terminal

      # Thumbnailers: webp/heic image loaders + video thumbnails
      webp-pixbuf-loader
      libheif
      ffmpegthumbnailer
    ];

    # Qt integration through the GNOME platform theme: QGnomePlatform reads
    # the active GTK settings so Qt apps (LibreOffice, ...) render in
    # Gruvbox/GNOME style without any KDE package. adwaita-dark satisfies
    # the gnome-platform-theme style assertion (see qt.nix in nixpkgs).
    qt.enable = true;
    qt.platformTheme = "gnome";
    qt.style = "adwaita-dark";

    # GNOME Keyring secret service for Wi-Fi passwords (NetworkManager),
    # libsecret clients and SSH key storage. PAM auto_start is added by
    # desktop/login/ly.nix; this keeps the service enabled regardless of
    # login manager.
    services.gnome.gnome-keyring.enable = true;
  };
}
