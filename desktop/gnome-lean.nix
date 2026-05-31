{ lib, pkgs, ... }:

let
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
    tracker-miners.enable = false;
    gnome-online-accounts.enable = lib.mkForce false;
  };

  environment.gnome.excludePackages =
    (optionalPkg [ "gnome-tour" ])
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
    ++ (optionalPkg [ "tracker-miners" ])
    ++ (optionalPkg [ "localsearch" ])
    ++ (optionalPkg [ "gnome" "gnome-tour" ])
    ++ (optionalPkg [ "gnome" "gnome-software" ])
    ++ (optionalPkg [ "gnome" "evolution" ]);

  environment.systemPackages = with pkgs; [
    gnome-tweaks
  ];

  programs.dconf.enable = true;
}
