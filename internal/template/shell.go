package template

import (
	"fmt"
	"path/filepath"
)

func (g *Generator) ShellModule(name string) ([]FileSpec, error) {
	name = sanitizeName(name)
	base := filepath.Join("home", "shell")

	if name != "" {
		base = filepath.Join("home", "shell", name)
	}

	files := []FileSpec{
		{
			Path: filepath.Join(base, "default.nix"),
			Content: fmt.Sprintf(`##############################################################################
#
# Home Manager Shell Configuration Module%s
#
# Purpose
# -------
# Aggregate and load all shell subsystem modules.
#
# Ownership
# ---------
# Imports only — no configuration.
#
##############################################################################

{ ... }:

{
  imports = [
    ./core
    ./integrations
    ./tools
    ./aliases
  ];
}
`, optionalSection(name)),
		},
		{
			Path: filepath.Join(base, "core", "default.nix"),
			Content: `{ ... }:

{
  imports = [ ];
}
`,
		},
		{
			Path: filepath.Join(base, "integrations", "default.nix"),
			Content: `{ ... }:

{
  imports = [ ];
}
`,
		},
		{
			Path: filepath.Join(base, "tools", "default.nix"),
			Content: `{ ... }:

{
  imports = [ ];
}
`,
		},
		{
			Path: filepath.Join(base, "aliases", "default.nix"),
			Content: `{ ... }:

{
  imports = [ ];
}
`,
		},
	}

	return files, nil
}

func optionalSection(s string) string {
	if s == "" {
		return ""
	}
	return " — " + capitalize(s)
}
