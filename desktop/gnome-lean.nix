# desktop/gnome-lean.nix
{ lib, pkgs, ... }:

let
  # Safely reference a package that may not exist in this nixpkgs revision.
  # Uses lib.attrByPath so a missing attr returns null rather than throwing.
  # NOTE: packages that use `throw` in their definition (renamed/removed pkgs)
  # will still hard-error even with attrByPath, so never list those here —
  # just omit them entirely.
  optionalPkg = path:
    let value = lib.attrByPath path null pkgs;
    in lib.optional (value != null) value;
in
{
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    excludePackages = [ pkgs.xterm ];
  };

  services.gnome = {
    core-apps.enable = false;
    core-developer-tools.enable = false;
    # tracker-miners was renamed to localsearch in nixos-unstable;
    # the option no longer exists — remove it to avoid "unknown option" errors.
    gnome-online-accounts.enable = lib.mkForce false;
  };

  environment.gnome.excludePackages =
    # localsearch is the current name of what was tracker-miners.
    # List it directly — optionalPkg is only needed for packages that may
    # or may not exist across nixpkgs versions.
    [ pkgs.localsearch ]
    ++ (optionalPkg [ "gnome-tour" ])
    ++ (optionalPkg [ "gnome-software" ])
    ++ (optionalPkg [ "gnome-music" ])
    ++ (optionalPkg [ "gnome-connections" ])
    ++ (optionalPkg [ "gnome-contacts" ])
    ++ (optionalPkg [ "gnome-maps" ])
    ++ (optionalPkg [ "gnome-weather" ])
    ++ (optionalPkg [ "gnome-calendar" ])
    ++ (optionalPkg [ "gnome-characters" ])
    ++ (optionalPkg [ "simple-scan" ])
    ++ (optionalPkg [ "yelp" ])
    ++ (optionalPkg [ "epiphany" ])
    ++ (optionalPkg [ "evolution" ])
    ++ (optionalPkg [ "totem" ])
    ++ (optionalPkg [ "gnome" "gnome-tour" ])
    ++ (optionalPkg [ "gnome" "gnome-software" ])
    ++ (optionalPkg [ "gnome" "evolution" ]);

  environment.systemPackages = with pkgs; [
    gnome-tweaks
  ];

  programs.dconf.enable = true;
}