package nixutil

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// systemProfileSymlink is the NixOS system profile symlink. The active
// generation number is embedded in the symlink target name as
// "system-<N>-link". This is world-readable and does not require the
// root-owned /nix/var/nix/profiles/system.lock that nix-env --list-generations
// needs for writing.
const systemProfileSymlink = "/nix/var/nix/profiles/system"

var genRe = regexp.MustCompile(`system-([0-9]+)-link`)

// CurrentGeneration reads the active NixOS generation number from the system
// profile symlink. Returns 0 on any error (symlink missing, parse failure).
// This avoids nix-env --list-generations which requires root lock access.
func CurrentGeneration() int {
	target, err := os.Readlink(systemProfileSymlink)
	if err != nil {
		return 0
	}
	return ParseGeneration(target)
}

// ParseGeneration extracts the generation number from a NixOS system profile
// symlink target (e.g. "/nix/var/nix/profiles/system-42-link" → 42).
// Returns 0 if the pattern does not match.
func ParseGeneration(symlinkTarget string) int {
	m := genRe.FindStringSubmatch(symlinkTarget)
	if len(m) < 2 {
		return 0
	}
	gen, _ := strconv.Atoi(m[1])
	return gen
}

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
