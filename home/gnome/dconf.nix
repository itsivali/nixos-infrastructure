{ config, lib, ... }:

{
  dconf.settings = {
    # Custom Waybar-style shell theme (see ~/.local/share/themes/gruvbox-waybar)
    "org/gnome/shell/extensions/user-theme" = {
      name = "gruvbox-waybar";
    };

    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "blur-my-shell@aunetx"
        "dash-to-panel@juliabelle.com"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "caffeine@patapon.info"
        "clipboard-indicator@tudmotu.com"
        "Vitals@CoreCoding.com"
        "appindicatorsupport@rgcjonas.gmail.com"
        "sound-output-device-chooser@kgshank.net"
        "just-perfection@just-perfection"
        "places-status-indicator@gnome-shell-extensions.gcampax.github.com"
        "rounded-window-corners@yilozt"
        "burn-my-windows@schneegans.github.com"
        "search-light@icedman.github.com"
        "logo-menu@ruzanov.email"
        "bluetooth-quick-connect@bjarosze.gmail.com"
        "color-picker@tuberry"
        "weather-oclock@nathanielw"
        "forge@gnome-shell-extensions.gcampax.github.com"
        "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
        "quick-settings-tweaker@qwreey"
        "focus-changer@hushml"
      ];
      development-tools = false;
      remember-mount-password = false;
      welcome-dialog-last-shown-version = "999";
    };

    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "orange";
      gtk-theme = "adw-gtk3-dark";
      icon-theme = "Tela-dark";
      cursor-theme = "Bibata-Modern-Ice";
      cursor-size = lib.gvariant.mkInt32 24;
      font-name = "Inter 11";
      document-font-name = "Liberation Serif 11";
      monospace-font-name = "JetBrains Mono 11";
      text-scaling-factor = 1.0;
      clock-format = "24h";
      clock-show-seconds = false;
      clock-show-date = true;
      clock-show-weekday = true;
      enable-animations = true;
    };

    "org/gnome/desktop/wm/preferences" = {
      button-layout = ":minimize,maximize,close,appmenu";
      titlebar-font = "Inter Bold 11";
      titlebar-uses-system-font = false;
      auto-maximize = true;
      focus-mode = "click";
      raise-on-click = true;
      cursor-theme = "Bibata-Modern-Ice";
    };

    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" ];
      minimize = [ "<Super>h" ];
      maximize = [ "<Super>k" ];
      toggle-maximized = [ "<Super>m" ];
      switch-to-workspace-left = [ "<Control><Super>Left" ];
      switch-to-workspace-right = [ "<Control><Super>Right" ];
      move-to-workspace-left = [ "<Shift><Control><Super>Left" ];
      move-to-workspace-right = [ "<Shift><Control><Super>Right" ];
      switch-windows = [ "<Super>Tab" ];
      switch-windows-backward = [ "<Shift><Super>Tab" ];
      switch-applications = [ "<Super>Tab" ];
      switch-applications-backward = [ "<Shift><Super>Tab" ];
      toggle-fullscreen = [ "<Super>f" ];
    };

    "org/gnome/shell/keybindings" = {
      toggle-overview = [ "<Super>" ];
      toggle-application-grid = [ "<Super>a" ];
    };

    "org/gnome/desktop/background" = {
      picture-uri = "file://${../../wallpapers/default.jpg}";
      picture-uri-dark = "file://${../../wallpapers/default.jpg}";
      picture-options = "zoom";
      primary-color = "#282828";
    };

    "org/gnome/desktop/screensaver" = {
      picture-uri = "file://${../../wallpapers/lockscreen.jpg}";
      picture-uri-dark = "file://${../../wallpapers/lockscreen.jpg}";
      primary-color = "#282828";
      lock-enabled = true;
      lock-delay = lib.gvariant.mkUint32 0;
      show-full-name-in-top-bar = false;
    };

    "org/gnome/desktop/lockdown" = {
      disable-lock-screen = false;
      disable-user-switching = false;
    };

    "org/gnome/desktop/session" = {
      idle-delay = lib.gvariant.mkUint32 0;
    };

    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-battery-type = "nothing";
      idle-dim = false;
    };

    "org/gnome/desktop/privacy" = {
      old-files-age = lib.gvariant.mkInt32 7;
      remove-old-trash-files = true;
      remove-old-temp-files = true;
    };

    "org/gnome/desktop/notifications" = {
      show-in-lock-screen = true;
      show-banners = true;
    };

    "org/gnome/desktop/notifications/application" = {
      show-in-lock-screen = false;
    };

    "org/gnome/desktop/peripherals/keyboard" = {
      repeat = true;
      delay = lib.gvariant.mkInt32 300;
      interval = lib.gvariant.mkInt32 30;
    };

    "org/gnome/desktop/peripherals/mouse" = {
      speed = 0.3;
      accel-profile = "flat";
      natural-scroll = false;
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      speed = 0.4;
      natural-scroll = true;
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
      disable-while-typing = true;
      accel-profile = "flat";
      click-method = "fingers";
    };

    "org/gnome/mutter" = {
      center-new-windows = true;
      edge-tiling = true;
      dynamic-workspaces = true;
    };

    "org/gnome/Console" = {
      theme-variant = "dark";
      font-size = lib.gvariant.mkInt32 11;
      audible-bell = false;
    };

    # Dash to Panel — slim Waybar-style top bar (Gruvbox)
    "org/gnome/shell/extensions/dash-to-panel" = {
      panel-position = "TOP";
      panel-size = lib.gvariant.mkInt32 32;
      dock-fixed = true;
      intellihide = false;
      transparency-mode = "FIXED";
      background-opacity = 0.55;
      background-color = "#282828";
      custom-background-color = true;
      show-running-apps = true;
      show-appmenu = true;
      show-window-title = true;
      show-apps-button = true;
      show-activities-button = false;
      running-indicator-style = "LINE";
      running-indicator-position = "BOTTOM";
      click-action = "focus-or-previews";
      hot-keys = false;
      multi-monitor = false;
      appicon-margin = lib.gvariant.mkInt32 4;
      appicon-padding = lib.gvariant.mkInt32 4;
    };

    # Forge — tiling (Hyprland/i3-like) + Gruvbox focus accent
    "org/gnome/shell/extensions/forge" = {
      tiling-mode-enabled = true;
      primary-layout-mode = "tiling";
      window-gap-size = lib.gvariant.mkUint32 12;
      window-gap-hidden-on-single = false;
      focus-border-size = lib.gvariant.mkUint32 3;
      focus-border-color = "rgba(254, 128, 25, 1)";
      split-border-color = "rgba(104, 157, 106, 1)";
      focus-on-hover-enabled = true;
    };

    "org/gnome/shell/extensions/blur-my-shell" = {
      sigma = lib.gvariant.mkInt32 30;
      brightness = 0.6;
    };

    "org/gnome/shell/extensions/blur-my-shell/panel" = {
      sigma = lib.gvariant.mkInt32 20;
      brightness = 0.7;
    };

    "org/gnome/shell/extensions/blur-my-shell/overview" = {
      sigma = lib.gvariant.mkInt32 40;
      brightness = 0.5;
    };

    "org/gnome/shell/extensions/blur-my-shell/appfolder-dialogs" = {
      sigma = lib.gvariant.mkInt32 30;
      brightness = 0.6;
    };

    "org/gnome/shell/extensions/burn-my-windows" = {
      close-effect = "greyscale";
      open-effect = "greyscale";
      animation-time = lib.gvariant.mkInt32 350;
    };

    "org/gnome/shell/extensions/just-perfection" = {
      hot-corner = false;
      startup-status = lib.gvariant.mkInt32 0;
      animation-duration = lib.gvariant.mkInt32 1;
      world-clock-weather = true;
      panel-in-overview = true;
      clock-menu-position = lib.gvariant.mkInt32 0;
      show-panel-in-overview = true;
      workspace-switcher-size = lib.gvariant.mkInt32 36;
      notification-banner = true;
    };

    "org/gnome/shell/extensions/caffeine" = {
      enable = false;
      show-indicator = true;
    };

    "org/gnome/shell/extensions/clipboard-indicator" = {
      disable-cache = false;
      cache-size = lib.gvariant.mkInt32 100;
    };

    "org/gnome/shell/extensions/vitals" = {
      show-fan = false;
      show-voltage = false;
      show-power = true;
      use-fahrenheit = false;
      position-in-panel = lib.gvariant.mkInt32 0;
    };

    "org/gnome/shell/extensions/rounded-window-corners" = {
      border-radius = lib.gvariant.mkInt32 12;
      keep-radius = true;
      shadow = true;
      crop-area = true;
    };

    "org/gnome/shell/extensions/logo-menu" = {
      icon-size = lib.gvariant.mkInt32 16;
    };

    "org/gnome/shell/extensions/quick-settings-tweaker" = {
      show-dark-mode-toggle = true;
      show-night-light-toggle = true;
    };

    "org/gnome/shell/calendar" = {
      show-weekdate = true;
    };

    "org/gnome/desktop/applications/terminal" = {
      exec = "gnome-console";
    };

    "org/gnome/desktop/applications/browser" = {
      exec = "firefox";
    };

    "org/gnome/desktop/applications/file-manager" = {
      exec = "nautilus";
    };
  };
}
