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
# - Modern key exchange, ciphers, and MAC hardening
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
      ports = [ cfg.port ];

      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = cfg.allowedUsers;

        # ── Authentication hardening ──────────────────────────────────
        MaxAuthTries = cfg.maxAuthTries;
        LoginGraceTime = cfg.loginGraceTime;

        # ── Session hardening ─────────────────────────────────────────
        X11Forwarding = false;
        KbdInteractiveAuthentication = false;
        PermitEmptyPasswords = false;
        ChallengeResponseAuthentication = false;
        UsePAM = false;

        # ── Keepalive (detect dead connections) ───────────────────────
        ClientAliveInterval = cfg.clientAliveInterval;
        ClientAliveCountMax = cfg.clientAliveCountMax;
      };

      extraConfig = ''
        # ── Modern key exchange (NIST-free) ────────────────────────────
        KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

        # ── Modern host key algorithms ────────────────────────────────
        HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256

        # ── Modern ciphers (AEAD only) ────────────────────────────────
        Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com

        # ── Modern MACs (EtM only) ────────────────────────────────────
        MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
      '';
    };

    # Inject authorised keys into each allowed user
    users.users = lib.genAttrs cfg.allowedUsers (_: {
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    });

    # Tailscale-only: open on tailscale0, leave closed globally
    networking.firewall.interfaces.tailscale0.allowedTCPPorts =
      lib.mkIf cfg.tailscaleOnly [ cfg.port ];

    # Non-restricted: open globally
    networking.firewall.allowedTCPPorts = lib.mkIf (!cfg.tailscaleOnly) [ cfg.port ];
  };
}
