package operations

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// generationService implements GenerationService.
type generationService struct{}

// NewGenerationService creates a generation service.
func NewGenerationService() *generationService {
	return &generationService{}
}

func (g *generationService) List(ctx context.Context) ([]Generation, error) {
	out, err := exec.CommandContext(ctx, "nix-env", "--list-generations",
		"--profile", "/nix/var/nix/profiles/system").CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("list generations: %w", err)
	}

	var generations []Generation
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}

		gen := Generation{}
		var err error
		gen.Number, err = strconv.Atoi(fields[0])
		if err != nil {
			continue
		}

		// Check if active
		gen.Active = strings.Contains(line, "*")

		// Parse date (format: 2026-08-24 10:30:00)
		if len(fields) >= 3 {
			dateStr := fields[1] + " " + fields[2]
			if t, err := time.Parse("2006-01-02 15:04:05", dateStr); err == nil {
				gen.Date = t
			}
		}

		generations = append(generations, gen)
	}

	return generations, nil
}

func (g *generationService) Current(ctx context.Context) (*Generation, error) {
	generations, err := g.List(ctx)
	if err != nil {
		return nil, err
	}

	for _, gen := range generations {
		if gen.Active {
			return &gen, nil
		}
	}

	if len(generations) > 0 {
		return &generations[len(generations)-1], nil
	}

	return nil, fmt.Errorf("no active generation found")
}
