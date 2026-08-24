##############################################################################
#
# SSH Options
#
# Purpose
# -------
# Option declarations for the SSH daemon module.
#
# Ownership
# ---------
# options.ivali.ssh
#
##############################################################################

{ lib, ... }:

{
  options.ivali.ssh = {
    enable = lib.mkEnableOption "SSH daemon";

    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users permitted to log in via SSH (sets AllowUsers).";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Public keys injected into every allowedUser's authorized_keys.";
      example = [ "ssh-ed25519 AAAAC3..." ];
    };

    tailscaleOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true, port 22 is opened only on the tailscale0 interface and
        kept closed on all other interfaces (including the public NIC).
        Set to false to allow SSH from anywhere.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = "Port the SSH daemon listens on.";
    };

    maxAuthTries = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = ''
        Maximum number of authentication attempts per connection.
        Reduces brute-force exposure. Default 3 (one primary + two retries).
      '';
    };

    clientAliveInterval = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = ''
        Seconds between server-initiated keepalive messages.
        Disconnects idle sessions after clientAliveInterval * clientAliveCountMax.
        Set to 0 to disable. Default 300 (5 minutes).
      '';
    };

    clientAliveCountMax = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = ''
        Number of keepalive messages before disconnecting an idle client.
        With default interval (300s) and count (3), idle sessions are
        dropped after 15 minutes.
      '';
    };

    loginGraceTime = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = ''
        Seconds the server waits for the user to authenticate before
        disconnecting. Prevents slow-loris-style SSH connection
        flooding. Set to 0 to disable (not recommended).
      '';
    };
  };
}
