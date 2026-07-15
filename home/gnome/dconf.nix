{ config, lib, ... }:

{
  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "blur-my-shell@aunetx"
        "dash-to-dock@micxgx.gmail.com"
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
        "nightthemeswitcher@romainvigier.fr"
        "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
        "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
        "quick-settings-tweaker@qwreey"
        "window-list@gnome-shell-extensions.gcampax.github.com"
        "focus-changer@hushml"
      ];
      development-tools = false;
      remember-mount-password = false;
      development-tools = false;
      remember-mount-password = false;
      welcome-dialog-last-shown-version = "999";
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Console.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.TextEditor.desktop"
        "org.gnome.Extensions.desktop"
      ];
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
      button-layout = "close:minimize,maximize,appmenu";
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

    "org/gnome/console" = {
      theme-variant = "dark";
      font-size = lib.gvariant.mkInt32 11;
      audible-bell = false;
    };

    "org/gnome/Console" = {
      theme-variant = "dark";
      font-size = lib.gvariant.mkInt32 11;
      audible-bell = false;
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      dock-fixed = true;
      autohide = false;
      intellihide = false;
      extend-area = true;
      dash-max-icon-size = lib.gvariant.mkInt32 22;
      custom-theme-shrink = false;
      transparency-mode = "FIXED";
      background-opacity = 1.0;
      background-color = "#282828";
      custom-background-color = true;
      running-indicator-style = "DOTS";
      running-indicator-color = "#fe8019";
      apply-custom-theme = true;
      show-trash = false;
      show-show-apps-button = false;
      show-dock = true;
      show-icons = true;
      show-windows-preview = true;
      hide-overview-on-startup = true;
      multi-monitor = false;
      preferred-monitor = lib.gvariant.mkInt32 (-2);
      hot-keys = false;
      click-action = "previews";
      scroll-action = "switch-workspace";
      shift-click-action = "launch";
      shift-scroll-action = "switch-workspace";
      height-fraction = 0.9;
      max-height = lib.gvariant.mkInt32 0;
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

    "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
      sigma = lib.gvariant.mkInt32 30;
      brightness = 0.6;
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

    "org/gnome/shell/extensions/night-theme-switcher" = {
      enabled = true;
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
