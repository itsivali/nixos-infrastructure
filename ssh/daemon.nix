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
# services.openssh, networking.firewall
#
# Responsibilities
# ----------------
# - Password authentication disabled (keys only)
# - Root login disabled
# - Optional Tailscale-only restriction (tailscale0 interface)
# - Per-user authorised key injection
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.ssh;
in
{
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
