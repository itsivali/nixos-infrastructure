##############################################################################
#
# Desktop — Common GPU
#
# Purpose
# -------
# AMD GPU driver, firmware, Vulkan, and display configuration.
#
# Ownership
# ---------
# boot.initrd.kernelModules, services.xserver.videoDrivers, hardware.graphics
#
# Does NOT Own
# ------------
# - Kernel parameters (boot/kernel.nix)
# - Display manager (desktop/login/gdm.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
