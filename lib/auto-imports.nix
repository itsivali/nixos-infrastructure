# lib/auto-imports.nix
#
# Automatically imports modules from a directory.
#
# Import order:
#   1. Root-level option files
#        options.nix
#        *-options.nix
#   2. Other root-level .nix modules
#   3. Subdirectories containing default.nix
#
# Skips:
#   - default.nix
#   - _*.nix helpers
#   - _* directories
#

dir:

let
  entries = builtins.readDir dir;
  names = builtins.attrNames entries;

  ############################################################
  # Predicates
  ############################################################

  isPrivate = name:
    builtins.match "_.*" name != null;

  isNixFile = name:
    entries.${name} == "regular"
    && builtins.match ".*\\.nix" name != null
    && name != "default.nix"
    && !isPrivate name;

  isOptionsFile = name:
    isNixFile name
    && (
      name == "options.nix"
      || builtins.match ".*-options\\.nix" name != null
    );

  isRegularModule = name:
    isNixFile name
    && !isOptionsFile name;

  isSubModule = name:
    entries.${name} == "directory"
    && !isPrivate name
    && builtins.pathExists (dir + "/${name}/default.nix");

  ############################################################
  # Deterministic ordering
  ############################################################

  sort = builtins.sort builtins.lessThan;

  optionFiles = sort (builtins.filter isOptionsFile names);
  moduleFiles = sort (builtins.filter isRegularModule names);
  subModules = sort (builtins.filter isSubModule names);

in

(map (n: dir + "/${n}") optionFiles)
++ (map (n: dir + "/${n}") moduleFiles)
++ (map (n: dir + "/${n}") subModules)
