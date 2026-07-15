##############################################################################
#
# Bootloader
#
# Purpose
# -------
# Systemd-boot configuration and EFI settings.
#
# Ownership
# ---------
# boot.loader, boot.tmp
#
# Does NOT Own
# ------------
# - Kernel parameters (boot/kernel.nix)
# - Sysctl tuning (boot/sysctl.nix)
# - zRAM (boot/zram.nix)
# - TPM (boot/tpm.nix)
#
##############################################################################

{ ... }:

{
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        consoleMode = "max";
      };

      timeout = 0;

      efi.canTouchEfiVariables = true;
      grub.enable = false;
    };

    tmp.cleanOnBoot = true;
  };
}
