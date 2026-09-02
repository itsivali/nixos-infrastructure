##############################################################################
#
# Nix Daemon
#
# Purpose
# -------
# Nix daemon settings, experimental features, garbage collection,
# and auto-upgrade.
#
# Ownership
# ---------
# nixpkgs.config.allowUnfree, nix.settings, nix.gc, system.autoUpgrade
#
# Does NOT Own
# ------------
# - Flake registry (N/A)
#
##############################################################################

{ username, gitlabUrl, hostName, ... }:

{
  nixpkgs.config.allowUnfree = true;

  documentation.doc.enable = false;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" username "gitlab-runner" ];
      substituters = [ "https://cache.nixos.org" ];
      warn-dirty = false;

      # Increase timeouts for slow/unstable connections (WiFi, VPN, etc.)
      timeout = 180;
      http-connections = 50;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 5d";
    };
  };

  system.autoUpgrade = {
    enable = false;
    flake = "git+${gitlabUrl}#${hostName}";
    flags = [
      "--refresh"
      "--print-build-logs"
    ];
    dates = "04:30";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };
}
