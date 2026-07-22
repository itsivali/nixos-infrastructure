##############################################################################
#
# Lib
#
# Purpose
# -------
# Barrel module for repository-level Nix helper functions (host templates,
# hardware detection, auto-imports). Not auto-imported; import directly.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Re-export hostTemplates, hardwareDetection, and autoImports helpers
#
##############################################################################

{
  hostTemplates = import ./host-templates;
  hardwareDetection = import ./hardware-detection.nix;
  autoImports = import ./auto-imports.nix;
}
