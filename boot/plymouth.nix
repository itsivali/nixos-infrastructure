##############################################################################
#
# Plymouth
#
# Purpose
# -------
# Graphical boot splash screen. Uses BGRT theme to display the
# Lenovo OEM logo from UEFI firmware through kernel init.
#
# Ownership
# ---------
# boot.plymouth
#
# Does NOT Own
# ------------
# - Kernel parameters (boot/kernel.nix) — quiet, splash
# - Bootloader (boot/loader.nix)
# - TPM (boot/tpm.nix)
#
##############################################################################

{ ... }:

{
  boot.plymouth = {
    enable = true;
  };
}
