{ hostTemplates, hardwareDetection, autoImports, ... }:

{
  inherit hostTemplates hardwareDetection autoImports;

  hostTemplates = import ./host-templates;
  hardwareDetection = import ./hardware-detection.nix;
  autoImports = import ./auto-imports.nix;
}