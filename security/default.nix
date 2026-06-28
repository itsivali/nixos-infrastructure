##############################################################################
#
# Security Module
#
# Purpose
# -------
# Compose security-related configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - sudo.nix      — Sudo hardening
# - hardening.nix — Kernel protection, PAM, audit, coredump
# - apparmor.nix  — AppArmor mandatory access control
# - fail2ban.nix  — Brute-force protection
# - packages.nix  — Security utilities
# - firewall.nix  — Nftables firewall
# - tailscale.nix — Tailscale VPN
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
