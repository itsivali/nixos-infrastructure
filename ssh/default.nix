##############################################################################
#
# SSH Daemon
#
# Purpose
# -------
# SSH daemon configuration with Tailscale-aware firewall controls.
#
# Ownership
# ---------
# options.ivali.ssh, services.openssh
#
# Responsibilities
# ----------------
# - Password authentication disabled (keys only)
# - Root login disabled
# - Optional Tailscale-only restriction (tailscale0 interface)
# - Per-user authorised key injection
#
# Does NOT Own
# ------------
# - SSH client config (ssh/client.nix)
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.ssh;
in
{
  imports = [ ./client.nix ];

  options.ivali.ssh = {
    enable = lib.mkEnableOption "SSH daemon";

    allowedUsers = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [];
      description = "Users permitted to log in via SSH (sets AllowUsers).";
    };

    authorizedKeys = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [];
      description = "Public keys injected into every allowedUser's authorized_keys.";
      example  = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCnLKiK4YHXCXTgVdStJZanUuZeKoc8uYBbRiNVTzS68uGCklMVmlrExpLE7e58hGP7JJhYvpCB27ysf7xoU41lNVdj6ZUXtNbBMxsraA3LctBVcBVaAuZd0qntzrcicvKKzDYP+O1PA293GU6xSXIWxFo+n+1GSYGZXreFZai0XlQidrHcobRb5YKD5gTU7DMeuRRvajt6KyKo10dzVDpFJsqDwCjY2NtIXJdhfpmXa0kWTg6XywyHUBvQE+o71UR55rAvlWpUWXnA09Pq3OgnyMYFJw0nF8093KU4KWqIyRPTEhCxxjiPn2xMlBiS//lXgmcLasXrJPJu+zZHpGFeeOUpnkgvFnpRPKyoMzlGeb4bA77QxuivEKwtIGQBO0xSWdINDw5eZ6SO4kEkFn+ShqxMpSop1nVo5HvQwxL5n5FBbSTXMtMjwwFhiN/JXUQllGKGF77LHX14se5qxUoekO8h/H1JA/snLQSOkbP9j75I09n6aZy4OUDBSO480xDiXQbUYrvVkizSb0UyrRWYUec7qTO9MTyGqBOmAVArk6GfvnpDSfBeGdTKgfjImR2j021ktb1wN3OTGHL5RwnSJoEcTesv3HI+6Q7XGnuZ24guIirqLkpI/wJQbYcpaWS7niee9wAZxt81iBe+y9wp8YgpS3liahTWhYaTy7gKsw== ShellFish@iPhone-03062026" ];
    };

    tailscaleOnly = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = ''
        When true, port 22 is opened only on the tailscale0 interface and
        kept closed on all other interfaces (including the public NIC).
        Set to false to allow SSH from anywhere.
      '';
    };

    port = lib.mkOption {
      type    = lib.types.port;
      default = 22;
      description = "Port the SSH daemon listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      ports  = [ cfg.port ];

      settings = {
        PasswordAuthentication = false;
        PermitRootLogin        = "no";
        AllowUsers             = cfg.allowedUsers;

        # Harden defaults
        X11Forwarding          = false;
        KbdInteractiveAuthentication = false;
      };
    };

    # Inject authorised keys into each allowed user
    users.users = lib.genAttrs cfg.allowedUsers (_: {
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    });

    # Tailscale-only: open on tailscale0, leave closed globally
    networking.firewall.interfaces.tailscale0.allowedTCPPorts =
      lib.mkIf cfg.tailscaleOnly [ cfg.port ];

    # Non-restricted: open globally
    networking.firewall.allowedTCPPorts =
      lib.mkIf (!cfg.tailscaleOnly) [ cfg.port ];
  };
}
