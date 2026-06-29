package template

import (
	"fmt"
	"os"
	"path/filepath"
)

func (g *Generator) EditorModule(name string) ([]FileSpec, error) {
	name = sanitizeName(name)
	base := filepath.Join("home", "editors")

	if info, err := os.Stat(filepath.Join(g.Root, base, name+".nix")); err == nil && !info.IsDir() {
		return nil, fmt.Errorf("editor module %s already exists", name)
	}

	files := []FileSpec{
		{
			Path: filepath.Join(base, name+".nix"),
			Content: fmt.Sprintf(`##############################################################################
#
# %s Editor
#
# Purpose
# -------
# Configure %s as a Home Manager editor.
#
# Ownership
# ---------
# programs.%s
#
# Responsibilities
# ----------------
# - Enable %s
# - Configure %s settings and preferences
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.editors.%s;
in

{
  options.ivali.editors.%s = {
    enable = lib.mkEnableOption "%s editor";

    package = lib.mkOption {
      type    = lib.types.package;
      default = pkgs.%s;
      description = "The %s package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    # TODO: add editor configuration
  };
}
`, capitalize(name), capitalize(name), name, capitalize(name), capitalize(name), name, name, capitalize(name), name, capitalize(name)),
		},
	}

	return files, nil
}
