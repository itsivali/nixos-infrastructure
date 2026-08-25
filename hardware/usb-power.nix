##############################################################################
#
# USB Power Management
#
# Purpose
# -------
# Disable aggressive runtime autosuspend on USB controllers. On Lenovo AMD
# laptops, the kernel's runtime PM suspends USB controllers (EHCI/xHCI)
# after a short idle period and fails to wake them when new devices are
# plugged in, causing all USB ports to become non-functional.
#
# The fix: a udev rule that sets power/control="on" for all USB controllers
# and USB devices, preventing the kernel from suspending them at runtime.
#
# Ownership
# ---------
# services.udev.extraRules (USB power states)
#
# Does NOT Own
# ------------
# - USB device restrictions (security/usb.nix)
# - Kernel parameters (boot/kernel.nix)
# - Audio stack (desktop/common/audio.nix)
#
##############################################################################

{ pkgs, ... }:

{
  services.udev.extraRules = ''
    # Disable USB runtime autosuspend globally.
    # On this Lenovo AMD laptop, the EHCI and xHCI controllers enter
    # suspended state and do not wake when new devices are plugged in.
    # This causes all USB ports to stop working after the initial boot
    # devices are removed or after a brief idle period.
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend_delay_ms}="0"
  '';
}
