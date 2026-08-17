package nixutil

import (
	"path/filepath"
	"strings"
)

// ResolveImportRel resolves a relative Nix import path against a module's location.
// If the import is absolute (starts with ./ or ../), it is resolved relative to
// the module's directory. Otherwise, the import path is returned as-is.
func ResolveImportRel(moduleRel, imp string) string {
	if strings.HasPrefix(imp, "./") || strings.HasPrefix(imp, "../") {
		resolved := filepath.Join(filepath.Dir(moduleRel), imp)
		resolved = filepath.Clean(resolved)
		if !strings.HasSuffix(resolved, ".nix") {
			resolved += "/default.nix"
		}
		return resolved
	}
	return imp
}
