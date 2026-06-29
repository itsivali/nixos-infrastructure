package template

import (
	"fmt"
	"os"
	"path/filepath"
)

func (g *Generator) DomainModule(name string) ([]FileSpec, error) {
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
# %s Module
#
# Purpose
# -------
# Compose %s-related configuration modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
##############################################################################

{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;
}
`, capitalize(name), name),
		},
		{
			Path: filepath.Join(name, "options.nix"),
			Content: fmt.Sprintf(`##############################################################################
#
# %s Options
#
# Purpose
# -------
# Declare configuration options for the %s module.
#
# Ownership
# ---------
# options.ivali.%s
#
# Responsibilities
# ----------------
# - Enable/disable the %s subsystem
# - Configure %s behaviour
#
##############################################################################

{ config, lib, ... }:

let
  cfg = config.ivali.%s;
in

{
  options.ivali.%s = {
    enable = lib.mkEnableOption "%s subsystem";
  };

  config = lib.mkIf cfg.enable {
    # TODO: add configuration
  };
}
`, capitalize(name), name, name, name, name, name, name, capitalize(name)),
		},
	}

	return files, nil
}
