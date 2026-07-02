##############################################################################
#
# System Users
#
# Purpose
# -------
# Declarative system user definitions.
#
# Ownership
# ---------
# users.users
#
# Does NOT Own
# ------------
# - User shell configuration (home/)
# - SSH authorized keys per-user (security/ssh/)
#
##############################################################################

{ username, ... }:

let
  gitlabSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrfkLmTc690z2/Mk2SJbymqiJEjqOdU3RR8V+sOghq5 itsivali@outlook.com";
in
{
  users.users.${username} = {
    isNormalUser = true;
    description = "Willis Ivali";
    extraGroups = [ "wheel" "networkmanager" "docker" "video" "audio" ];

    openssh.authorizedKeys.keys = [
      gitlabSshKey
    ];
  };
}
