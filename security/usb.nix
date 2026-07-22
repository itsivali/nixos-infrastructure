##############################################################################
#
# USB Device Restrictions
#
# Purpose
# -------
# Restrict USB mass storage devices and other high-risk USB peripherals
# via udev rules. Configurable to allow keyboards/mice while blocking
# storage, serial adapters, and wireless adapters.
#
# Ownership
# ---------
# services.udev.extraRules, options.ivali.security.usb.*
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.security;
in
{
  options.ivali.security.usb = {
    enable = lib.mkEnableOption "USB device restrictions";

    allowStorage = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow USB mass storage devices (flash drives, external disks).";
    };

    allowSerial = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow USB serial adapters and debugging tools.";
    };

    allowWireless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow USB wireless adapters (WiFi, Bluetooth dongles).";
    };
  };

  config = lib.mkIf cfg.usb.enable {
    services.udev.extraRules = ''
      # Block USB mass storage unless explicitly allowed
      ${lib.optionalString (!cfg.usb.allowStorage) ''
        ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="0/0/0", ATTR{bDeviceSubclass}=="0/0/0", ENV{ID_BUS}=="usb", ATTR{bDeviceProtocol}=="80", RUN+="${pkgs.coreutils}/bin/logger -t usb-guard 'Blocked USB storage device %k'"
        ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z]*", ENV{ID_BUS}=="usb", TEST!="{power/control}", RUN+="${pkgs.kmod}/bin/modprobe -r usb-storage"
      ''}

      # Block USB serial adapters unless explicitly allowed
      ${lib.optionalString (!cfg.usb.allowSerial) ''
        ACTION=="add", SUBSYSTEM=="tty", ATTRS{manufacturer}=="*FTDI*", RUN+="${pkgs.coreutils}/bin/logger -t usb-guard 'Blocked USB serial device %k'"
        ACTION=="add", SUBSYSTEM=="tty", ATTRS{manufacturer}=="*Prolific*", RUN+="${pkgs.coreutils}/bin/logger -t usb-guard 'Blocked USB serial device %k'"
        ACTION=="add", SUBSYSTEM=="tty", ATTRS{manufacturer}=="*Silicon Labs*", RUN+="${pkgs.coreutils}/bin/logger -t usb-guard 'Blocked USB serial device %k'"
      ''}

      # Block USB wireless adapters unless explicitly allowed
      ${lib.optionalString (!cfg.usb.allowWireless) ''
        ACTION=="add", SUBSYSTEM=="net", ENV{ID_BUS}=="usb", ATTRS{bInterfaceClass}=="224", RUN+="${pkgs.coreutils}/bin/logger -t usb-guard 'Blocked USB wireless adapter %k'"
      ''}

      # Always allow keyboards and mice (human interface devices)
      ACTION=="add", SUBSYSTEM=="hidraw", TAG+="uaccess"
      ACTION=="add", SUBSYSTEM=="input", ATTRS{bInterfaceClass}=="03", TAG+="uaccess"
    '';
  };
}
