##############################################################################
#
# zRAM
#
# Purpose
# -------
# Compressed RAM swap for improved memory pressure handling.
#
# Ownership
# ---------
# zramSwap
#
# Does NOT Own
# ------------
# - Kernel parameters (boot/kernel.nix)
# - Sysctl tuning (boot/sysctl.nix)
# - Bootloader (boot/loader.nix)
# - TPM (boot/tpm.nix)
#
##############################################################################

{ ... }:

{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    priority = 100;
  };
}
