##############################################################################
#
# Home Identity
#
# Purpose
# -------
# Own the Home Manager user identity.
#
# Ownership
# ---------
# home.username, home.homeDirectory, home.stateVersion,
# programs.home-manager.enable, home.enableNixpkgsReleaseCheck
#
# Does NOT Own
# ------------
# - Shell configuration (home/shell/)
# - Git configuration (home/git/)
# - Editor configuration (home/editors/)
# - Environment variables (home/environment/)
# - User services (home/services/)
#
##############################################################################

{ username, ... }:

{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.11";
  };

  programs.home-manager.enable = true;
  home.enableNixpkgsReleaseCheck = false;
}
