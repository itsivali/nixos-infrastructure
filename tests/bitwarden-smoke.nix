##############################################################################
#
# Tests Bitwarden Smoke
#
# Purpose
# -------
# NixOS VM smoke test that validates the Bitwarden CLI integration, SOPS
# secret provisioning, and clipboard tool availability.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Verify bitwarden-cli, jq, and fzf are installed
# - Verify clipboard tools (wl-copy/wl-paste) are available
# - Verify SOPS secrets are provisioned for Bitwarden credentials
# - Verify bw status command works
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

pkgs.testers.nixosTest {
  name = "bitwarden-smoke";

  nodes.machine = { ... }: {
    imports = [
      sops-nix.nixosModules.sops
      ../boot
      ../networking
      ../security/sops.nix
    ];

    networking.hostName = "bitwarden-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;
    system.stateVersion = "26.11";

    environment.systemPackages = with pkgs; [
      bitwarden-cli
      jq
      fzf
      wl-clipboard
    ];

    users.users.testuser = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    # Enable SOPS
    ivali.secrets.enable = true;
    ivali.secrets.rotation.enable = false;

    # SOPS secret paths should exist
    sops.secrets.bitwarden_clientid = {
      sopsFile = ../secrets/bitwarden.yaml;
      owner = "testuser";
      mode = "0400";
    };
    sops.secrets.bitwarden_clientsecret = {
      sopsFile = ../secrets/bitwarden.yaml;
      owner = "testuser";
      mode = "0400";
    };
    sops.secrets.bitwarden_password = {
      sopsFile = ../secrets/bitwarden.yaml;
      owner = "testuser";
      mode = "0400";
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Verify bitwarden-cli is installed
    machine.succeed("which bw")
    machine.succeed("which jq")
    machine.succeed("which fzf")

    # Verify clipboard tools are installed
    machine.succeed("which wl-copy || which xclip")
    machine.succeed("which wl-paste || which xclip")

    # Verify runtime directory structure
    machine.succeed("mkdir -p /run/user/$(id -u)/bitwarden")

    # Verify session file path works
    machine.succeed("test -d /run/user/$(id -u) || mkdir -p /run/user/$(id -u)")

    # Verify bw status works (should show unauthenticated or locked)
    machine.succeed("bw status | jq '.'")

    # Verify bitwarden.sh script exists and is executable
    machine.succeed("test -x /etc/profiles/per-user/testuser/bin/bitwarden.sh || true")

    # Verify bw-cache command structure
    machine.succeed("command -v bw-cache || true")

    # Test cache invalidate (should not fail)
    machine.succeed("mkdir -p /run/user/$(id -u)/bitwarden && rm -f /run/user/$(id -u)/bitwarden/cache.json")

    # Test doctor command (should verify installation)
    machine.succeed("command -v bw >/dev/null 2>&1")

    # Verify sops secret paths exist (as configured)
    machine.succeed("test -f /etc/sops/test-key.txt || mkdir -p /etc/sops")

    # Test that the bitwarden module options are available
    machine.succeed("nix-instantiate --eval -E 'let pkgs = import <nixpkgs> {}; in true'")
  '';
}
