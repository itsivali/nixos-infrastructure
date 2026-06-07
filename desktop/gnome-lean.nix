# desktop/gnome.nix
{ config
, pkgs
, lib
, ...
}:

let
  # Flip to true only when you need GNOME Remote Desktop (RDP/VNC via pipewire).
  # Keeps the service + its heavy deps out of the closure by default.
  remoteDesktopEnabled = false;
in
{
  ##########################################################
  # DISPLAY — GDM + Wayland
  ##########################################################

  services.xserver.enable = true;

  # xterm is useless on a GNOME Wayland desktop.
  services.xserver.excludePackages = [ pkgs.xterm ];

  services.displayManager.gdm = {
    enable = true;
    # Auto-suspend after 20 min on the login screen (saves power on laptops).
    autoSuspend = true;
  };

  services.desktopManager.gnome.enable = true;

  ##########################################################
  # CORE GNOME SERVICES
  # core-apps.enable = true pulls in Nautilus, gnome-terminal,
  # and other first-party essentials automatically.
  ##########################################################

  services.gnome = {
    core-apps.enable = true;
    core-developer-tools.enable = false;

    # Online-accounts daemon — only needed for Google/Microsoft
    # account integration. Disable for a clean desktop.
    gnome-online-accounts.enable = lib.mkForce false;

    # Tinysparql (formerly Tracker) + LocalSearch index files
    # for Nautilus search. Disable if unused — saves RAM/CPU.
    tinysparql.enable = lib.mkForce false;
    localsearch.enable = lib.mkForce false;

    # Software centre replaced by Nix.
    gnome-software.enable = lib.mkForce false;
    gnome-user-share.enable = lib.mkForce false;

    # Rygel = DLNA/UPnP media server — rarely wanted.
    rygel.enable = lib.mkForce false;
    games.enable = lib.mkForce false;

    # Keyring is lightweight and prevents repeated unlock prompts.
    gnome-keyring.enable = true;

    gnome-remote-desktop.enable = lib.mkForce remoteDesktopEnabled;
  };

  ##########################################################
  # PACKAGEKIT — disable (Nix manages packages)
  ##########################################################

  services.packagekit.enable = false;

  ##########################################################
  # GEOLOCATION — off unless you use Maps or Weather
  ##########################################################

  services.geoclue2.enable = lib.mkForce false;

  ##########################################################
  # STORAGE + VIRTUAL FILESYSTEMS
  # gvfs    → Nautilus trash, MTP, SFTP, SMB mounts
  # udisks2 → automounting USB drives / SD cards
  ##########################################################

  services.gvfs.enable = true;
  services.udisks2.enable = true;

  ##########################################################
  # KEYRING — PAM integration so it unlocks at login
  ##########################################################

  security.pam.services = {
    login.enableGnomeKeyring = true;
    gdm.enableGnomeKeyring = true;
  };

  ##########################################################
  # POLKIT — required by many desktop privilege operations
  ##########################################################

  security.polkit.enable = true;

  ##########################################################
  # USER ACCOUNTS DAEMON
  # Required for GDM user list and avatar support.
  ##########################################################

  services.accounts-daemon.enable = true;

  ##########################################################
  # DCONF — settings database (required by most GNOME apps)
  ##########################################################

  programs.dconf.enable = true;

  ##########################################################
  # XDG PORTALS
  # xdg-desktop-portal-gnome  → file picker, screen share, etc.
  # xdg-desktop-portal-gtk    → fallback portal for non-GNOME apps
  ##########################################################

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
    config.gnome.default = [ "gnome" "gtk" ];
  };

  ##########################################################
  # WAYLAND ENVIRONMENT VARIABLES
  # NIXOS_OZONE_WL     → native Wayland in Electron/Chromium
  # MOZ_ENABLE_WAYLAND → Firefox native Wayland
  # GTK_USE_PORTAL     → GTK file-chooser via xdg-portal
  # CLUTTER_BACKEND    → helps GNOME shell with Wayland selection
  ##########################################################

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    GTK_USE_PORTAL = "1";
    CLUTTER_BACKEND = "wayland";
  };

  ##########################################################
  # FONTS — hinting & anti-aliasing defaults
  ##########################################################

  fonts.fontconfig = {
    enable = true;
    antialias = true;
    hinting.enable = true;
    hinting.style = "slight"; # "none" | "slight" | "medium" | "full"
    subpixel.rgba = "rgb"; # match your panel (rgb most common)
    subpixel.lcdfilter = "default";
  };

  ##########################################################
  # POWER MANAGEMENT (laptop-friendly defaults)
  # upower  → battery monitoring
  # logind  → lid / power-button / idle behaviour
  ##########################################################

  services.upower.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
    HandlePowerKey = "suspend";
    IdleAction = "suspend";
    IdleActionSec = "30min";
  };

  ##########################################################
  # PRINTING (disabled — enable + add driver if needed)
  ##########################################################

  services.printing.enable = false;
  # services.printing.drivers = [ pkgs.gutenprint ];

  ##########################################################
  # BLUETOOTH
  ##########################################################

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # don't waste power if BT is rarely used
    settings.General.Experimental = "true"; # battery % in GNOME
  };

  services.blueman.enable = true;

  ##########################################################
  # SYSTEM PACKAGES — GNOME tooling on top of core-apps
  ##########################################################

  environment.systemPackages =
    with pkgs;
    [
      # GNOME configuration & introspection
      gnome-tweaks
      gnome-extension-manager
      dconf-editor

      # Disk usage analyser
      baobab

      # Archive manager (zip, tar, 7z …)
      file-roller
    ]
    ++ lib.optionals remoteDesktopEnabled [
      gnome-remote-desktop
    ];

  ##########################################################
  # BLOAT REMOVAL
  ##########################################################

  environment.gnome.excludePackages = with pkgs; [
    # Indexer — disabled above, exclude the package too
    localsearch

    # Software centre — Nix handles this
    gnome-software
    gnome-initial-setup

    # Browser + tour
    epiphany
    gnome-tour

    # Media apps you likely don't want
    gnome-music
    gnome-photos
    gnome-weather
    gnome-maps
    gnome-contacts
    totem

    # Misc
    simple-scan
    yelp
    gnome-calendar
    gnome-characters
    evolution
  ];
}
