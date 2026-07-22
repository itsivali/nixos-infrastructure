##############################################################################
#
# Jules Security Hardening
#
# Purpose
# -------
# Security policies and sandboxing for the Google Jules CLI.
# Restricts network access, filesystem access, and runtime permissions.
#
# Ownership
# ---------
# ivali.jules.security options, systemd sandboxing
#
# Does NOT Own
# ------------
# - Jules CLI installation (developer/jules.nix)
# - SOPS secrets (security/sops.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.jules;
in
{
  options.ivali.jules = {
    sandbox = lib.mkEnableOption "Jules sandboxing (restrict filesystem and network)" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Systemd service hardening for the Jules bot service (if running as a
    # long-lived process). This is a reference profile — the actual service
    # is defined in services/bot/.
    systemd.services.ivali-jules = lib.mkIf cfg.sandbox {
      serviceConfig = {
        # Sandboxing
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        RestrictFilesystems = lib.mkDefault [ "/sys" "/proc" "/dev" ];
        SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
        SystemCallArchitectures = "native";

        # Network access (Jules needs HTTPS to Google APIs)
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];

        # Capabilities
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";

        # User
        DynamicUser = true;
      };
    };
  };
}
