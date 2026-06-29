package template

import (
	"fmt"
	"os"
	"path/filepath"
)

func (g *Generator) PackageSet(name string) ([]FileSpec, error) {
	name = sanitizeName(name)
	dir := filepath.Join("packages", name)

	if info, err := os.Stat(filepath.Join(g.Root, dir)); err == nil && info.IsDir() {
		return nil, fmt.Errorf("package set %s already exists", name)
	}

	files := []FileSpec{
		{
			Path: filepath.Join(dir, "default.nix"),
			Content: fmt.Sprintf(`# packages/%s/default.nix
# %s package set — adds CLI + desktop packages.
{ config, lib, pkgs, ... }:

{
  environment.systemPackages =
    (import ./cli { inherit pkgs; })
    ++ (import ./desktop { inherit pkgs; });
}
`, name, capitalize(name)),
		},
		{
			Path: filepath.Join(dir, "cli.nix"),
			Content: fmt.Sprintf(`# packages/%s/cli.nix
# CLI packages for %s.
{ pkgs }:

with pkgs;

[
  # TODO: add CLI packages
]
`, name, capitalize(name)),
		},
		{
			Path: filepath.Join(dir, "desktop.nix"),
			Content: fmt.Sprintf(`# packages/%s/desktop.nix
# Desktop packages for %s.
{ pkgs }:

with pkgs;

[
  # TODO: add desktop packages
]
`, name, capitalize(name)),
		},
	}

	return files, nil
}
