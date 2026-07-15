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

# TPM 2.0 disabled — not used for LUKS, Secure Boot, or PKCS#11.
# Eliminates ~180s boot delay from tpm0/tpmrm0 device waits.
{ }
