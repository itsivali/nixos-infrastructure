##############################################################################
#
# Overlays
#
# Purpose
# -------
# Barrel of repository nixpkgs overlays. Consumed by flake.nix (for the flake's
# package set) and by system/nix.nix (nixpkgs.overlays for the host).
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - List every repository overlay in application order
#
# Does NOT Own
# ------------
# - nixpkgs.overlays wiring itself (owned by system/nix.nix)
# - Individual overlay behaviour (owned by each overlay file)
#
##############################################################################

[
  (import ./anyio-tests.nix)
  (import ./collabora-desktop.nix)
]
