##############################################################################
#
# BTRFS
#
# Purpose
# -------
# BTRFS filesystem tuning and optimization.
#
# Ownership
# ---------
# boot.kernel.sysctl for BTRFS, BTRFS mount options
#
# Does NOT Own
# ------------
# - Specific mount points (hosts/hardware-configuration.nix)
# - Logical volume management (storage/lvm.nix, future)
# - Encryption (storage/encryption.nix, future)
#
##############################################################################

{ ... }:

{
  fileSystems."/".options = [ "compress-force=zstd:3" "noatime" ];
  fileSystems."/home".options = [ "subvol=home" "compress-force=zstd:3" "noatime" ];
  fileSystems."/nix".options = [ "subvol=nix" "compress-force=zstd:3" "noatime" ];
}
