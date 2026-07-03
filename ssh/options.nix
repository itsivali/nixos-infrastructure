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
      type    = lib.types.listOf lib.types.str;
      default = [];
      description = "Users permitted to log in via SSH (sets AllowUsers).";
    };

    authorizedKeys = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [];
      description = "Public keys injected into every allowedUser's authorized_keys.";
      example  = [ "ssh-rsa AAAAB3..." ];
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
}
