package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/itsivali/nixos-infrastructure/internal/architecture"
)

func main() {
	// Find the repository root by walking up to find flake.nix
	repoRoot, err := findRepoRoot()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	linter, err := architecture.New(repoRoot)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error initializing linter: %v\n", err)
		os.Exit(1)
	}

	result := linter.Run()

	// Print header
	fmt.Println("Architecture Validation")
	fmt.Println("========================")
	fmt.Println()

	// Print check results
	checkNames := []string{
		"forbidden_imports",
		"circular_dependencies",
		"filesystem_boundaries",
		"duplicate_ownership",
		"declared_dependencies",
		"internal_api_boundaries",
		"service_state_ownership",
	}

	checkStatus := make(map[string]bool)
	for _, v := range result.Violations {
		checkStatus[v.Check] = true
	}

	for _, name := range checkNames {
		if checkStatus[name] {
			fmt.Printf("  ✗ %s\n", name)
		} else {
			fmt.Printf("  ✓ %s\n", name)
		}
	}

	fmt.Println()

	// Print violations
	if len(result.Violations) > 0 {
		fmt.Printf("Found %d violation(s):\n\n", len(result.Violations))
		for _, v := range result.Violations {
			fmt.Println(architecture.FormatViolation(v))
			fmt.Println()
		}
	}

	// Print summary
	fmt.Println("========================")
	if result.Passed {
		fmt.Println("Architecture: PASS")
	} else {
		fmt.Println("Architecture: FAIL")
	}

	if !result.Passed {
		os.Exit(1)
	}
}

// findRepoRoot walks up from the current directory to find flake.nix.
func findRepoRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	for {
		flakePath := filepath.Join(dir, "flake.nix")
		if _, err := os.Stat(flakePath); err == nil {
			return dir, nil
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	return "", fmt.Errorf("could not find repository root (no flake.nix found)")
}
