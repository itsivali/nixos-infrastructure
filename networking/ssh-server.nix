##############################################################################
#
# SSH Server
#
# Purpose
# -------
# OpenSSH server and client configuration.
#
# Ownership
# ---------
# services.openssh, programs.ssh
#
# Does NOT Own
# ------------
# - Time zone (networking/time.nix)
# - NetworkManager (networking/networkmanager.nix)
# - Email relay (networking/msmtp/)
# - SSH authorized keys per user (ssh/default.nix)
#
##############################################################################

{ ... }:

{
  services.openssh = {
    enable = true;
    openFirewall = false;

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  programs.ssh = {
    knownHosts.gitlab-com = {
      hostNames = [ "gitlab.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
    };

    startAgent = false;
  };
}
