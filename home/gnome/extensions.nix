##############################################################################
#
# Home — GNOME Shell Extensions
#
# Purpose
# -------
# Per-user enablement + preferences for the curated GNOME Shell extension set
# (packages installed by desktop/gnome/extensions.nix). Extension packages do
# not expose their UUIDs in nixpkgs, so the UUIDs below were extracted from
# each extension's metadata.json at the pinned nixpkgs revision.
#
# Ownership
# ---------
# dconf.settings."org/gnome/shell".enabled-extensions,
# dconf.settings."org/gnome/shell/extensions/*"
#
# Extension UUID reference
# ------------------------
#   dash-to-panel                 dash-to-panel@jderose9.github.com
#   blur-my-shell                 blur-my-shell@aunetx
#   appindicator                  appindicatorsupport@rgcjonas.gmail.com
#   user-themes                   user-theme@gnome-shell-extensions.gcampax.github.com
#   just-perfection               just-perfection-desktop@just-perfection
#   tiling-assistant              tiling-assistant@leleat-on-github
#   clipboard-indicator           clipboard-indicator@tudmotu.com
#   impatience                    impatience@gfxmonk.net
#   vitals                        Vitals@CoreCoding.com
#   caffeine                      caffeine@patapon.info
#
# Every value below was cross-checked against the extension GSettings schema
# at the pinned nixpkgs revision (see the schema dumps in the migration notes).
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "dash-to-panel@jderose9.github.com"
        "blur-my-shell@aunetx"
        "appindicatorsupport@rgcjonas.gmail.com"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "just-perfection-desktop@just-perfection"
        "tiling-assistant@leleat-on-github"
        "clipboard-indicator@tudmotu.com"
        "impatience@gfxmonk.net"
        "Vitals@CoreCoding.com"
        "caffeine@patapon.info"
      ];
    };

    # ── dash-to-panel: full-width top panel with a centered taskbar ────
    # Replaces both the stock top bar and the dash. Panel color = Gruvbox
    # bgHard (#1d2021) at 90% opacity so the blur-my-shell frosted effect
    # keeps the desktop readable underneath. The per-monitor JSON keys
    # below mirror what dash-to-panel's own preferences write for the
    # primary monitor ("0"); element names/positions come from
    # panelPositions.js at the pinned rev.
    "org/gnome/shell/extensions/dash-to-panel" = {
      panel-size = 44;
      # Per-monitor panel state (JSON strings): "0" = primary monitor.
      panel-positions = ''{"0":"TOP"}'';
      panel-lengths = ''{"0":100}'';
      panel-anchors = ''{"0":"MIDDLE"}'';
      panel-sizes = ''{"0":44}'';
      panel-element-positions = ''
        {"0":[{"element":"showAppsButton","visible":true,"position":"stackedTL"},{"element":"activitiesButton","visible":false,"position":"stackedTL"},{"element":"leftBox","visible":true,"position":"stackedTL"},{"element":"taskbar","visible":true,"position":"centered"},{"element":"centerBox","visible":false,"position":"centered"},{"element":"rightBox","visible":true,"position":"stackedBR"},{"element":"dateMenu","visible":true,"position":"stackedBR"},{"element":"systemMenu","visible":true,"position":"stackedBR"},{"element":"desktopButton","visible":false,"position":"stackedBR"}]}
      '';

      # Group windows of the same app into one launcher entry (default).
      group-apps = true;

      # Never let Super+(0-9) launch apps from the taskbar — the number row
      # stays free for normal typing.
      hot-keys = false;

      # Own the whole top edge: drop the stock GNOME dash and top bar.
      stockgs-keep-dash = false;
      stockgs-keep-top-panel = false;

      # Gruvbox translucent panel: bgHard at 90% opacity.
      trans-use-custom-bg = true;
      trans-bg-color = "#1d2021";
      trans-use-custom-opacity = true;
      trans-panel-opacity = 0.9;

      # Metro running-window dots (matches the top-bar accent).
      dot-style-focused = "METRO";
      dot-style-unfocused = "METRO";
      dot-position = "BOTTOM";
    };

    # ── blur-my-shell: frost the panel (Gruvbox translucency) ─────────
    # Global enable is on by default; declared explicitly so a settings
    # reset cannot silently disable it. Panel keeps the default sigma 30.
    "org/gnome/shell/extensions/blur-my-shell" = {
      blur = true;
      sigma = 30;
      brightness = 0.6;
    };

    # ── user-theme: load the Gruvbox Shell theme (from the custom package
    #    packages/gnome-shell-gruvbox-theme, installed via home.packages) ─
    "org/gnome/shell/extensions/user-theme" = {
      name = "gruvbox-shell";
    };

    # ── just-perfection: declutter the overview ──────────────────────────
    # Boot straight to the desktop (no overview), hide the window-picker
    # icon clutter, and disable the stock overview dash (dash-to-panel owns
    # app launching in the top panel).
    "org/gnome/shell/extensions/just-perfection" = {
      startup-status = 0;
      window-picker-icon = false;
      dash = false;
    };

    # ── tiling-assistant: comfortable window gaps ────────────────────────
    "org/gnome/shell/extensions/tiling-assistant" = {
      window-gap = 8;
      single-screen-gap = 8;
      maximize-with-gap = true;
    };

    # ── clipboard-indicator: clipboard history ──────────────────────────
    "org/gnome/shell/extensions/clipboard-indicator" = {
      history-size = 50;
      cache-images = true;
      paste-button = true;
      notify-on-copy = false;
    };

    # ── impatience: 2x faster Shell animations (0.5 vs default 0.75) ────
    "org/gnome/shell/extensions/net/gfxmonk/impatience" = {
      speed-factor = 0.5;
    };

    # ── vitals: compact CPU / RAM / battery gauges in the top panel ─────
    # hot-sensors selects what renders next to the icon; the *_usage_
    # pseudo-sensors aggregate each category's readings.
    "org/gnome/shell/extensions/vitals" = {
      hot-sensors = [ "_processor_usage_" "_memory_usage_" ];
      show-processor = true;
      show-memory = true;
      show-battery = true;
      hide-icons = false;
      update-time = 2;
    };

    # ── caffeine: keep the display awake on demand ─────────────────────
    # Disabled at login (the user opts in via the indicator toggle);
    # fullscreen media never sleeps the display; state persists across
    # restarts via restore-state.
    "org/gnome/shell/extensions/caffeine" = {
      user-enabled = false;
      enable-fullscreen = true;
      restore-state = true;
    };
  };
}
