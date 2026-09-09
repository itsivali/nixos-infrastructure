##############################################################################
#
# Desktop — Login (GDM)
#
# Purpose
# -------
# GDM (GNOME Display Manager) login manager for the GNOME desktop. GDM
# provides a Wayland-native greeter that integrates seamlessly with GNOME
# Shell and inherits the system GTK theme and cursor automatically.
#
# Ownership
# ---------
# services.displayManager.gdm
#
# Responsibilities
# ----------------
# - Present the GDM greeter (Wayland-native with GNOME 50)
# - Launch the GNOME session by default (defaultSession = "gnome")
#
##############################################################################

{ config, lib, ... }:

{
  config = lib.mkIf (config.ivali.desktop.enable or false) {
    # ── GDM display manager ─────────────────────────────────────────────
    # With GNOME 50 the greeter is always native Wayland; there is no
    # opt-out, so the (removed) `wayland` option is intentionally absent.
    services.displayManager.gdm.enable = true;

    # Boot straight into the GNOME session.
    services.displayManager.defaultSession = "gnome";
  };
}
