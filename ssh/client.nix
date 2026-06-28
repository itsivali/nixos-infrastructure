##############################################################################
#
# SSH Client
#
# Purpose
# -------
# SSH client configuration — known hosts, agent settings.
#
# Ownership
# ---------
# programs.ssh
#
# Does NOT Own
# ------------
# - SSH daemon/server (ssh/default.nix)
#
##############################################################################

{ ... }:

{
  programs.ssh = {
    knownHosts.gitlab-com = {
      hostNames = [ "gitlab.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
    };

    startAgent = false;
  };
}
