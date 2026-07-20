##############################################################################
#
# Hardware Detection
#
# Purpose
# -------
# Provides utilities for detecting and generating hardware configuration
# during host bootstrap. Used by `ivali bootstrap host` to capture
# the current machine's hardware configuration.
#
# Ownership
# ---------
# lib.hardwareDetection
#
##############################################################################

{ pkgs, lib, ... }:

{
  ############################################################################
  # HARDWARE DETECTION SCRIPT
  ############################################################################
  lib.hardwareDetection = {
    # Generate hardware configuration for current machine
    generateConfig = pkgs.writeShellScriptBin "generate-hardware-config" ''
      #!/usr/bin/env bash
      # Generate hardware configuration for current machine
      # Output: hardware-configuration.nix compatible format
      set -euo pipefail

      echo "Generating hardware configuration..."

      # Use nixos-generate-config to detect hardware
      nixos-generate-config --show-hardware-config
    '';

    # Detect CPU vendor (intel/amd/other)
    detectCpuVendor = pkgs.writeShellScriptBin "detect-cpu-vendor" ''
      #!/usr/bin/env bash
      set -euo pipefail
      vendor=$(grep -m1 "vendor_id" /proc/cpuinfo | cut -d: -f2 | tr -d ' ')
      case "$vendor" in
        GenuineIntel) echo "intel" ;;
        AuthenticAMD) echo "amd" ;;
        *) echo "unknown" ;;
      esac
    '';

    # Detect GPU vendor
    detectGpuVendor = pkgs.writeShellScriptBin "detect-gpu-vendor" ''
      #!/usr/bin/env bash
      set -euo pipefail
      lspci_output=$(lspci 2>/dev/null || true)
      if echo "$lspci_output" | grep -qi "nvidia"; then
        echo "nvidia"
      elif echo "$lspci_output" | grep -qi "amd\|ati"; then
        echo "amd"
      elif echo "$lspci_output" | grep -qi "intel.*graphics\|intel.*display"; then
        echo "intel"
      else
        echo "unknown"
      fi
    '';

    # Detect if running in VM
    detectVm = pkgs.writeShellScriptBin "detect-vm" ''
      #!/usr/bin/env bash
      set -euo pipefail
      if systemd-detect-virt --quiet 2>/dev/null; then
        systemd-detect-virt
      else
        echo "none"
      fi
    '';

    # Detect disk layout
    detectDisks = pkgs.writeShellScriptBin "detect-disks" ''
      #!/usr/bin/env bash
      set -euo pipefail
      lsblk -J -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID 2>/dev/null || lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID
    '';
  };
}
