##############################################################################
#
# Tailscale ACL Policy
#
# Purpose
# -------
# Manages the declarative Tailscale ACL policy file and provides a service
# to apply it via the Tailscale API.
#
# Ownership
# ---------
# security/tailscale.nix (parent module)
#
# Responsibilities
# ----------------
# - Deploy policy.hujson to /etc/tailscale/policy.hujson
# - Provide a systemd service to apply the policy via the Tailscale API
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.tailscale;

  policyFile = ./tailscale-policy.hujson;

in
{
  options.ivali.tailscale = {
    enablePolicy = lib.mkEnableOption "Tailscale ACL policy management";

    applyPolicy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Create a systemd service that applies the ACL policy on boot.
        Requires TAILSCALE_AUTH_KEY to be set in the environment (via
        sops-nix or another secrets manager).
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.enablePolicy) {
    # Deploy the policy file
    environment.etc."tailscale/policy.hujson".source = policyFile;

    # Apply the policy on boot (if enabled)
    systemd.services.ivali-tailscale-acl = lib.mkIf cfg.applyPolicy {
      description = "Apply Tailscale ACL policy";

      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      requires = [ "tailscaled.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        # Wait for tailscaled to be ready
        for i in $(seq 1 30); do
          if tailscale status >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        POLICY_FILE="/etc/tailscale/policy.hujson"

        if [ ! -f "$POLICY_FILE" ]; then
          echo "ERROR: Policy file not found at $POLICY_FILE"
          exit 1
        fi

        # Apply the policy via the Tailscale API
        # This requires a TAILSCALE_AUTH_KEY with ACL write permissions
        if [ -z "''${TAILSCALE_AUTH_KEY:-}" ]; then
          echo "WARNING: TAILSCALE_AUTH_KEY not set, skipping ACL policy application"
          exit 0
        fi

        echo "Applying Tailscale ACL policy..."
        ${pkgs.curl}/bin/curl -s -X POST \
          -H "Authorization: Bearer $TAILSCALE_AUTH_KEY" \
          -H "Content-Type: application/json" \
          -d @"$POLICY_FILE" \
          "https://api.tailscale.com/api/v2/tailnet/${cfg.tailnetDomain}/acl"

        echo "ACL policy applied successfully"
      '';
    };
  };
}
