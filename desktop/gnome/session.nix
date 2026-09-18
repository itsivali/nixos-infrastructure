##############################################################################
#
# Desktop — GNOME Session & Applications
#
# Purpose
# -------
# System-level GNOME session configuration: GNOME Shell over Wayland via
# GDM, a minimal GNOME application stack, power management, Bluetooth,
# and input configuration.
#
# Ownership
# ---------
# ivali.desktop.gnome
#
# Responsibilities
# ----------------
# - Enable the GNOME desktop manager over Wayland
# - Enable GDM as the display manager (Wayland-native greeter)
# - Enable power management (upower)
# - Enable Bluetooth explicitly
# - Install a minimal, memory-efficient GNOME application stack
# - Configure libinput (touchpad config)
# - Keyboard layout: us, ctrl:nocaps
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    # ── GNOME Shell desktop manager ─────────────────────────────
    services.desktopManager.gnome.enable = true;

    # GNOME requires the X server for some components even under Wayland.
    services.xserver.enable = true;

    # Required for dconf settings (GNOME desktop preferences, extensions).
    programs.dconf.enable = true;

    # ── GDM display manager (Wayland greeter) ─────────────────────
    services.displayManager.gdm = {
      enable = true;
      autoSuspend = false;
    };

    # Boot straight into the GNOME session.
    services.displayManager.defaultSession = "gnome";

    # ── GNOME Keyring (shared secret service) ────────────────────
    # Wi-Fi password storage (NetworkManager), libsecret clients and
    # GNOME Remote Desktop credentials depend on the freedesktop
    # secret service.
    services.gnome.gnome-keyring.enable = true;

    # ── Power management ──────────────────────────────────────────
    # powerManagement.enable drives upower + logind power handling.
    # power-profiles-daemon provides balanced/performance/power-saver
    # profiles via D-Bus, exposed by the GNOME Quick Settings.
    powerManagement.enable = true;
    services.power-profiles-daemon.enable = true;

    # ── Bluetooth ─────────────────────────────────────────────────
    # Enable Bluetooth explicitly so headphones, keyboards and mice work.
    # The WirePlumber Bluetooth codec configuration ships in desktop/common.
    hardware.bluetooth.enable = true;
    hardware.bluetooth.settings = {
      General = {
        AutoEnable = true;
      };
    };

    # ── Input / Touchpad ──────────────────────────────────────────
    services.libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        disableWhileTyping = true;
        scrollMethod = "twofinger";
      };
    };

    # ── Keyboard layout ───────────────────────────────────────────
    services.xserver.xkb = {
      layout = "us";
      options = "ctrl:nocaps";
    };

    # ── Minimal GNOME application stack ───────────────────────────
    # Stripped down for memory efficiency. Heavy or web-replaceable
    # apps (software, calendar, contacts, maps, weather, totem, etc.)
    # are excluded. Vitals extension provides system monitoring.
    environment.systemPackages = with pkgs; [
      gnome-shell
      gnome-session
      mutter
      gnome-control-center
      nautilus
      gnome-console
      gnome-text-editor
      gnome-disk-utility
    ];

    # ── Exclude unnecessary GNOME packages ───────────────────────
    environment.gnome.excludePackages = with pkgs; [
      gnome-music
      gnome-tour
      epiphany
    ];
  };
}
