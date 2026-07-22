##############################################################################
#
# Lib Auto-Imports
#
# Purpose
# -------
# Provides a function that automatically discovers and imports NixOS modules
# from a directory, with deterministic ordering (options first, then modules,
# then subdirectories).
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Scan a directory for .nix files and subdirectories with default.nix
# - Import options.nix and *-options.nix files first, then other modules
# - Skip private files (prefixed with _) and default.nix itself
# - Return a sorted, deterministic list of module paths
#
##############################################################################

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
