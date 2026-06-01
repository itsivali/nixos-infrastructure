# desktop/gnome-lean.nix
# Compatible with nixos-unstable as of 2025+.
# All GNOME packages moved from pkgs.gnome.* to pkgs.* (top-level) in 2024.
# pkgs.gnome.* now throws for every moved package — do not use that scope.
# gnome-tour and gnome-connections were removed from nixpkgs entirely.
{ lib, pkgs, ... }:
{
  services.xserver = {
    enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
    excludePackages = [ pkgs.xterm ];
  };

  services.gnome = {
    core-apps.enable = false;
    core-developer-tools.enable = false;
    # tracker-miners.enable was removed — the package was renamed to localsearch
    # and the services.gnome.tracker-miners option no longer exists.
    gnome-online-accounts.enable = lib.mkForce false;
  };

  environment.gnome.excludePackages = with pkgs; [
    # tracker-miners was renamed to localsearch in nixos-unstable
    localsearch
    # all of these moved from pkgs.gnome.* to top-level pkgs.* in 2024
    gnome-software
    gnome-music
    gnome-contacts
    gnome-maps
    gnome-weather
    gnome-calendar
    gnome-characters
    simple-scan
    yelp
    epiphany
    evolution
    totem
    # gnome-tour and gnome-connections were removed from nixpkgs entirely —
    # do not reference them at all, not even via optionalPkg.
  ];

  environment.systemPackages = with pkgs; [
    gnome-tweaks
  ];

  programs.dconf.enable = true;
}
