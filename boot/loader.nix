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

      # Non-zero so the previous-generation recovery entry is reachable
      # without holding a key (critical for safe rollbacks).
      timeout = 3;

      efi.canTouchEfiVariables = true;
      grub.enable = false;
    };

    tmp.cleanOnBoot = true;
  };
}
