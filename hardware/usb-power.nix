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
# The fix: (1) usbcore.autosuspend=-1 kernel param disables autosuspend
# globally, (2) udev rules keep host controllers and devices permanently
# awake via power/control="on" and power/autosuspend="-1".
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
    # Keep USB host controllers (usb0, usb1, …) permanently awake.
    # KERNEL=="usb[0-9]*" matches the root-level controller devices
    # (xhci_pci, ehci_pci), not individual USB peripherals. These
    # controllers must never enter runtime-suspend or all ports die.
    SUBSYSTEM=="usb", KERNEL=="usb[0-9]*", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"

    # Also force every USB device (flash drives, hubs, peripherals)
    # to stay awake on add and when state changes. The "change"
    # action catches devices that the kernel re-evaluates after
    # initial enumeration.
    ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
  '';
}
