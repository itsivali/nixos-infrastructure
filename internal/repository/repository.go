package repository

import (
	"os"
	"path/filepath"
)

type Repository struct {
	Root string
}

func Detect(path string) (*Repository, bool) {
	abs, err := filepath.Abs(path)
	if err != nil {
		return nil, false
	}

	candidate := abs
	for {
		flakePath := filepath.Join(candidate, "flake.nix")
		if info, err := os.Stat(flakePath); err == nil && !info.IsDir() {
			return &Repository{Root: candidate}, true
		}
		parent := filepath.Dir(candidate)
		if parent == candidate {
			break
		}
		candidate = parent
	}

	return nil, false
}
