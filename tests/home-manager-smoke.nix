##############################################################################
#
# Tests Home Manager Smoke
#
# Purpose
# -------
# NixOS VM smoke test that validates Home Manager integration, verifying
# that user packages (zsh, git) are installed and configured correctly.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Verify zsh is installed for the test user
# - Verify git user.name and user.email are configured via Home Manager
# - Verify home directory and .zshrc exist
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

pkgs.testers.nixosTest {
  name = "home-manager-smoke";

  nodes.machine = { pkgs, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      ../boot
      ../networking
    ];

    networking.hostName = "home-manager-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;
    system.stateVersion = "26.11";

    users.users.testuser = {
      isNormalUser = true;
      home = "/home/testuser";
      shell = pkgs.zsh;
      ignoreShellProgramCheck = true;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.testuser = {
        home.username = "testuser";
        home.homeDirectory = "/home/testuser";
        home.stateVersion = "26.11";
        programs.zsh.enable = true;
        programs.git.enable = true;
        programs.git.settings.user.name = "Test User";
        programs.git.settings.user.email = "test@example.com";
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Zsh installed
    machine.succeed("which zsh")

    # Git configured
    machine.succeed("su - testuser -c 'git config user.name' | grep -q Test")
    machine.succeed("su - testuser -c 'git config user.email' | grep -q test@example.com")

    # Home directory exists
    machine.succeed("test -d /home/testuser")

    # Zsh config exists
    machine.succeed("test -f /home/testuser/.zshrc")
  '';
}
