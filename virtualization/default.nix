##############################################################################
#
# Virtualization Module
#
# Purpose
# -------
# Compose virtualization-related configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - docker.nix  — Docker container runtime
# - kvm.nix     — KVM/QEMU (future)
# - podman.nix  — Podman (future)
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
