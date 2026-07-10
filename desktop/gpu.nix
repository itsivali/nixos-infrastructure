##############################################################################
#
# GPU — AMD
#
# Purpose
# -------
# AMD GPU driver and initrd configuration.
#
# Ownership
# ---------
# boot.initrd.kernelModules, services.xserver.videoDrivers, hardware.graphics
#
##############################################################################

{ ... }:

{
  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
