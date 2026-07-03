{ pkgs }:

pkgs.testers.nixosTest {
  name = "home-manager-smoke";

  nodes.machine = { pkgs, ... }: {
    imports = [
      ../boot
      ../networking
      ../system
    ];

    networking.hostName = "home-manager-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;
    system.stateVersion = "26.11";

    users.users.testuser = {
      isNormalUser = true;
      home = "/home/testuser";
      shell = pkgs.zsh;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.testuser = {
        home.stateVersion = "26.11";
        programs.zsh.enable = true;
        programs.git.enable = true;
        programs.git.userName = "Test User";
        programs.git.userEmail = "test@example.com";
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
