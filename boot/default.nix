##############################################################################
#
# Boot Module
#
# Purpose
# -------
# Compose boot-related configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
# Responsibilities
# ----------------
# - kernel.nix  — Kernel selection, modules, and parameters
# - sysctl.nix  — Kernel and network sysctl tuning
# - loader.nix  — Bootloader and tmp cleanup
# - tpm.nix     — TPM 2.0 support
# - zram.nix    — Compressed RAM swap
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
