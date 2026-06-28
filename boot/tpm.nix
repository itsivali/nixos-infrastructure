##############################################################################
#
# TPM 2.0
#
# Purpose
# -------
# Enable and configure TPM 2.0 support.
#
# Ownership
# ---------
# security.tpm2
#
# Does NOT Own
# ------------
# - Kernel parameters (boot/kernel.nix)
# - Sysctl tuning (boot/sysctl.nix)
# - Bootloader (boot/loader.nix)
# - zRAM (boot/zram.nix)
#
##############################################################################

{ ... }:

{
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };
}
