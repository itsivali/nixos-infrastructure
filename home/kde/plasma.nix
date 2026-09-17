##############################################################################
#
# Home Manager — KDE Plasma 6 (plasma-manager)
#
# Purpose
# -------
# Declarative KDE Plasma 6 configuration via plasma-manager. Covers the
# complete keyboard-first workspace: theme, effects, KWin shortcuts,
# virtual desktops, Konsole profile, Dolphin, and KRDP.
#
# Upstream design tokens (Garuda Mokka / Catppuccin Mocha Mauve)
# ============================================================
# Accent:      203,166,247 (Mauve)
# Background:  30,30,46
# Foreground: 205,214,244
#
# Ownership
# ---------
# programs.plasma.*
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  wallpaperPath = ../../wallpapers/default.jpg;
in
{
  programs.plasma.enable = true;

  # ── Workspace ────────────────────────────────────────────────────────
  programs.plasma.workspace = {
    theme = "breeze-dark";
    colorScheme = "Mokka";
    iconTheme = "Tela-circle-dracula-dark";
    widgetStyle = "Kvantum";
    lookAndFeel = null;

    wallpaper = wallpaperPath;

    cursor = {
      theme = "Catppuccin-Mocha-Mauve-Cursors";
      size = 24;
    };

    splashScreen = {
      engine = null;
      theme = "None";
    };

    windowDecorations = {
      library = null;
      theme = null;
    };

    clickItemTo = "open";
    tooltipDelay = 4;
  };

  # ── KWin Effects & Layout ──────────────────────────────────────────
  programs.plasma.kwin = {
    virtualDesktops = {
      number = 4;
      rows = 1;
      names = [ "Work" "Browse" "Chat" "Misc" ];
    };

    borderlessMaximizedWindows = true;

    effects = {
      blur = {
        enable = true;
        strength = 6;
        noiseStrength = 3;
      };

      wobblyWindows.enable = true;

      desktopSwitching = {
        animation = "slide";
        navigationWrapping = false;
      };

      windowOpenClose.animation = "scale";
      minimization.animation = "magiclamp";
      minimization.duration = 200;

      translucency.enable = true;
      snapHelper.enable = true;
      dimInactive.enable = false;
      fallApart.enable = false;
    };

    cornerBarrier = false;
    edgeBarrier = 0;

    titlebarButtons.left = [ "keep-above-windows" ];
    titlebarButtons.right = [ "minimize" "maximize" "close" ];
  };

  # ── Keyboard-First Shortcuts ──────────────────────────────────────────
  programs.plasma.shortcuts = {
    # ── KWin window management ────────────────────────────────────────────
    kwin = {
      # Window operations
      "Window Close" = "Meta+Q";
      "Window Maximize" = "Meta+M";
      "Window Fullscreen" = "Meta+F";

      # Quick tiling (keyboard-first workflow)
      "Window Quick Tile Left" = "Meta+H";
      "Window Quick Tile Right" = "Meta+L";
      "Window Quick Tile Top" = "Meta+K";
      "Window Quick Tile Bottom" = "Meta+J";

      # Desktop switching
      "Switch to Desktop 1" = "Meta+1";
      "Switch to Desktop 2" = "Meta+2";
      "Switch to Desktop 3" = "Meta+3";
      "Switch to Desktop 4" = "Meta+4";

      # Move window between desktops
      "Move Window to Desktop 1" = "Meta+Shift+1";
      "Move Window to Desktop 2" = "Meta+Shift+2";
      "Move Window to Desktop 3" = "Meta+Shift+3";
      "Move Window to Desktop 4" = "Meta+Shift+4";

      # Overview / Expose
      "Overview" = "Meta+W";
    };

    # ── KRunner ───────────────────────────────────────────────────────
    "services/org.kde.krunner.desktop" = { "_launch" = "Meta+Space"; };

    # ── System: logout / lock ─────────────────────────────────────────
    org_kde_ksmserver = {
      "Lock Session" = "Meta+Alt+L";
      "Logout" = "Meta+Shift+Q";
    };

    # ── App launchers (via services/ prefix) ──────────────────────────
    "services/org.kde.dolphin.desktop" = { "_launch" = "Meta+E"; };
    "services/org.kde.konsole.desktop" = { "_launch" = "Meta+T"; };
    "services/org.kde.spectacle.desktop" = {
      "_launch" = "Print";
      "FullScreenScreenShot" = [ "Shift+Print" ];
    };
  };

  # ── KRunner settings ────────────────────────────────────────────────
  # Launch shortcut set above in programs.plasma.shortcuts.

  # ── KConfig files ──────────────────────────────────────────────────
  programs.plasma.configFile = {
    # KWin: ModifierOnly shortcuts + Wayland primary selection
    "kwinrc" = {
      "ModifierOnlyShortcuts" = {
        Meta = "org.kde.plasmashell,/PlasmaShell,org.kde.plasmashell,activateLauncher";
      };
      "Wayland"."EnablePrimarySelection" = true;
    };

    # Konsole: default profile
    "konsolerc" = {
      "Desktop Entry"."DefaultProfile" = "Mokka.profile";
      "General"."ShowWindowtype" = false;
    };

    # Dolphin
    "dolphinrc" = {
      "General" = {
        RememberState = false;
        ShowToolbar = true;
        ShowStatusBar = true;
      };
      "Details Mode" = {
        ShowPreview = false;
        SortRole = "";
        SortOrder = 0;
      };
      "PreviewSettings"."Plugins" = "image/thumbnail,video/thumbnail,inode/directory";
      "Search"."History" = "[]";
    };

    # baloo: basic indexing only
    "baloofilerc" = {
      "Basic Settings"."Indexing Enabled" = true;
      "indexing-advanced"."onlyBasicIndexing" = true;
    };

    # KScreenlocker
    "kscreenlockerrc" = {
      "Greeter/LockScreen" = {
        theme = "org.kde.breeze.desktop";
      };
    };
  };

  # ── Konsole profile data ──────────────────────────────────────────────
  programs.plasma.dataFile."konsole/Mokka.profile" = {
    General = {
      Name = "Mokka";
      Parent = "FALLBACK";
    };
    "Appearance Option" = {
      ColorScheme = "Mokka";
      Font = "MesloLGS NF,11,-1,5,400,0,0,0,0,0";
      TerminalMargin = "4";
    };
    "Scrolling" = {
      HistoryMode = 2;
      HistoryLines = 10000;
    };
    "Interaction Options" = {
      CopyTextAsHTML = false;
      UrlHintsModifiers = 0;
    };
  };

  # ── Packages ────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    catppuccin-kvantum
    kdePackages.qt6ct
    kdePackages.sddm-kcm
    kdePackages.kcmutils
    kdePackages.kde-cli-tools
  ];

  # ── Session variables ───────────────────────────────────────────────
  home.sessionVariables = {
    XCURSOR_THEME = "Catppuccin-Mocha-Mauve-Cursors";
    XCURSOR_SIZE = "24";
  };
}
