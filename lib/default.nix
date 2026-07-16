# lib/default.nix
#
# Nix helper functions for the repository.
# This file is excluded from auto-import by configuration.nix.
# Import individual files directly as needed.

{
  hostTemplates = import ./host-templates;
  hardwareDetection = import ./hardware-detection.nix;
  autoImports = import ./auto-imports.nix;
}
