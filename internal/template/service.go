package template

import (
	"fmt"
	"os"
	"path/filepath"
)

func (g *Generator) ServiceModule(name string) ([]FileSpec, error) {
	name = sanitizeName(name)
	dir := filepath.Join(g.Root, name)

	if info, err := os.Stat(dir); err == nil && info.IsDir() {
		return nil, fmt.Errorf("directory %s already exists", name)
	}

	files := []FileSpec{
		{
			Path: filepath.Join(name, "default.nix"),
			Content: fmt.Sprintf(`##############################################################################
#
# %s Service
#
# Purpose
# -------
# Configure the %s service.
#
# Ownership
# ---------
# options.ivali.%s, services.%s
#
# Responsibilities
# ----------------
# - Enable/disable the %s service
# - Configure %s behaviour
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.%s;
in

{
  options.ivali.%s = {
    enable = lib.mkEnableOption "%s service";

    package = lib.mkOption {
      type    = lib.types.package;
      default = pkgs.%s;
      description = "The %s package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    # TODO: add service configuration
  };
}
`, capitalize(name), name, name, name, name, name, name, name, capitalize(name), name, name),
		},
	}

	return files, nil
}
