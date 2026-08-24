##############################################################################
#
# SSH Client
#
# Purpose
# -------
# SSH client configuration — known hosts, agent settings.
#
# Ownership
# ---------
# programs.ssh
#
# Does NOT Own
# ------------
# - SSH daemon/server (ssh/default.nix)
#
##############################################################################

{ config, lib, hostSpec, ... }:

let
  tailnetDomain = hostSpec.tailnetDomain or null;
  hostName = hostSpec.hostName or null;
  # Tailscale SSH host key (from `tailscale ssh-hostkey` on the target).
  # This is a well-known Tailscale-internal key; the actual per-host key
  # is verified by Tailscale's ACL system, not by SSH trust-on-first-use.
  tailscaleSSHKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH+YUTVNFHZi8+sTO1aMnGIVk3TjA61T2YFBTcM6/dRZ ssh-host-key";

  # Build the known hosts set
  baseKnownHosts = {
    gitlab-com = {
      hostNames = [ "gitlab.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
    };
  };

  # Add Tailscale host keys for all machines on the tailnet.
  # Prevents SSH TOFU (trust-on-first-use) prompts when connecting
  # to peers via MagicDNS.
  tailscaleKnownHosts = lib.optionalAttrs (tailnetDomain != null && hostName != null) {
    "tailscale-${hostName}" = {
      hostNames = [ "${hostName}.${tailnetDomain}" "${hostName}" ];
      publicKey = tailscaleSSHKey;
    };
  };
in
{
  programs.ssh = {
    knownHosts = baseKnownHosts // tailscaleKnownHosts;

    startAgent = false;

    extraConfig = ''
      # ── Keepalive (detect dead connections) ───────────────────────
      ServerAliveInterval 60
      ServerAliveCountMax 3

      # ── Modern algorithms (match daemon defaults) ─────────────────
      # Prefer Ed25519 host keys
      HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
      # Prefer modern key exchange
      KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
      # Prefer AEAD ciphers
      Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
      # Prefer EtM MACs
      MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
    '';
  };
}
