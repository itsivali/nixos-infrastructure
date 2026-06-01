# desktop/gnome-lean.nix

{ lib, pkgs, ... }:

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
    wayland = true;
    # Auto-suspend after 20 min on the login screen (saves power on laptops).
    autoSuspend = true;
  };

  services.desktopManager.gnome.enable = true;

  ##########################################################
  # GNOME SERVICES — disable what you don't need
  ##########################################################

  services.gnome = {
    # core-apps pulls in a large set of first-party GNOME apps.
    # Set true if you rely on any (Files, Calendar, Contacts …).
    core-apps.enable = false;
    core-developer-tools.enable = false;

    # Online-accounts daemon is only needed if you use GNOME integration
    # with Google/Microsoft/etc. accounts. Disable for a clean desktop.
    gnome-online-accounts.enable = lib.mkForce false;

    # Tinysparql (formerly Tracker) + LocalSearch index your files for
    # search in Nautilus. Disable if you don't use that feature.
    tinysparql.enable = lib.mkForce false;
    localsearch.enable = lib.mkForce false;

    # Software centre is replaced by Nix — no need for PackageKit either.
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
  # gvfs  → Nautilus trash, MTP, SFTP, SMB mounts
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

    # Let each DE claim its own portals; fall back to any available.
    config.common.default = "*";
    config.gnome.default = [ "gnome" "gtk" ];
  };

  ##########################################################
  # WAYLAND ENVIRONMENT VARIABLES
  # NIXOS_OZONE_WL  → enables native Wayland in Electron/Chromium apps
  # MOZ_ENABLE_WAYLAND → Firefox native Wayland
  # GTK_USE_PORTAL  → route GTK file-chooser through xdg-portal
  # CLUTTER_BACKEND → helps older GNOME shell with Wayland selection
  ##########################################################

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    GTK_USE_PORTAL = "1";
    CLUTTER_BACKEND = "wayland";
  };

  ##########################################################
  # FONTS — hinting & anti-aliasing defaults
  # These dconf keys are the GNOME-level fallback; per-user
  # settings in Home Manager take precedence.
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
  # upower monitors battery; logind handles lid/power-button.
  ##########################################################

  services.upower.enable = true;

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "lock"; # just lock when on AC
    extraConfig = ''
      HandlePowerKey=suspend
      IdleAction=suspend
      IdleActionSec=30min
    '';
  };

  ##########################################################
  # PRINTING (optional — comment out if you have no printer)
  ##########################################################

  services.printing.enable = false;
  # services.printing.drivers = [ pkgs.gutenprint ];  # add your driver

  ##########################################################
  # BLUETOOTH (optional — comment out if unused)
  ##########################################################

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # don't waste power if you don't use BT often
    settings.General.Experimental = "true"; # enables battery % in GNOME
  };

  services.blueman.enable = true;

  ##########################################################
  # SYSTEM PACKAGES — minimal GNOME tooling
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
  # gnome-tour and gnome-connections no longer exist in
  # nixpkgs — do NOT reference them here.
  ##########################################################

  environment.gnome.excludePackages = with pkgs; [
    # tracker-miners was renamed to localsearch in nixos-unstable
    localsearch

    # Software centre — Nix handles this
    gnome-software
    gnome-initial-setup

    # First-party apps you likely don't want
    gnome-music
    gnome-photos
    gnome-contacts
    gnome-maps
    gnome-weather
    gnome-calendar
    gnome-characters

    # Misc
    simple-scan
    yelp
    epiphany # GNOME Web / Epiphany browser
    evolution # email + calendar suite
    totem # GNOME Videos
  ];
}
