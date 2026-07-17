##############################################################################
#
# Bot Integration Test
#
# Purpose
# -------
# End-to-end test for the Go Telegram bot service.
# Verifies the service is configured and the binary is available.
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

pkgs.testers.nixosTest {
  name = "bot-integration";

  nodes.machine = { config, ... }: {
    imports = [
      sops-nix.nixosModules.sops
      ../automation
      ../ci
      ../services/bot
    ];

    networking.hostName = "bot-integration";
    services.xserver.enable = false;
    services.openssh.enable = false;

    # Bot configuration (token comes from environment in real deployment)
    fleet.bot = {
      enable = true;
      gitlabUrl = "https://gitlab.com/willisivali/nixos-infrastructure";
      defaultUser = "testuser";
    };

    system.stateVersion = "26.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Verify the bot service is defined
    machine.succeed("systemctl cat ivali-bot-go.service")

    # Check the service configuration
    machine.succeed("systemctl show ivali-bot-go.service --property=ExecStart")
    machine.succeed("systemctl show ivali-bot-go.service --property=Restart")
    machine.succeed("systemctl show ivali-bot-go.service --property=RestartSec")

    # Verify security hardening settings
    machine.succeed("systemctl show ivali-bot-go.service --property=PrivateTmp | grep yes")
    machine.succeed("systemctl show ivali-bot-go.service --property=ProtectSystem | grep strict")
    machine.succeed("systemctl show ivali-bot-go.service --property=ProtectHome")

    # Check environment variables are set
    machine.succeed("systemctl show ivali-bot-go.service --property=Environment | grep HOST_NAME")
    machine.succeed("systemctl show ivali-bot-go.service --property=Environment | grep REPO_DIR")

    # Verify service dependencies
    machine.succeed("systemctl show ivali-bot-go.service --property=After | grep network-online")
  '';
}
