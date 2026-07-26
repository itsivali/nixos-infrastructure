package docs

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/parser"
	"github.com/itsivali/nixos-infrastructure/internal/scanner"
)

type AnalysisResult struct {
	ModulePath   string   `json:"module_path"`
	HasDocHeader bool     `json:"has_doc_header"`
	HasPurpose   bool     `json:"has_purpose"`
	HasOwnership bool     `json:"has_ownership"`
	HasImports   bool     `json:"has_imports"`
	HasOptions   bool     `json:"has_options"`
	DocQuality   float64  `json:"doc_quality"`
	Suggestions  []string `json:"suggestions"`
	CrossRefs    []string `json:"cross_refs"`
	Complexity   int      `json:"complexity"`
	Dependencies []string `json:"dependencies"`
}

type DocMetrics struct {
	TotalModules      int     `json:"total_modules"`
	DocumentedModules int     `json:"documented_modules"`
	AverageQuality    float64 `json:"average_quality"`
	TotalSuggestions  int     `json:"total_suggestions"`
	CoveragePercent   float64 `json:"coverage_percent"`
}

func AnalyzeModule(path string, info *parser.ModuleInfo) *AnalysisResult {
	result := &AnalysisResult{
		ModulePath: path,
	}

	if info == nil {
		return result
	}

	result.HasDocHeader = info.DocHeader != ""
	result.HasPurpose = info.Purpose != ""
	result.HasOwnership = len(info.Owns) > 0
	result.HasImports = len(info.Imports) > 0
	result.HasOptions = info.HasOptions

	// Calculate documentation quality score
	score := 0.0
	if result.HasDocHeader {
		score += 0.4
		if len(info.DocHeader) > 100 {
			score += 0.1
		}
	}
	if result.HasPurpose {
		score += 0.3
	}
	if result.HasOwnership {
		score += 0.2
	}
	if len(info.Imports) > 0 {
		score += 0.1
	}

	result.DocQuality = score

	// Generate suggestions
	if !result.HasDocHeader {
		result.Suggestions = append(result.Suggestions, "Add documentation header with purpose and ownership")
	} else {
		if !result.HasPurpose {
			result.Suggestions = append(result.Suggestions, "Add explicit purpose section to documentation")
		}
		if !result.HasOwnership {
			result.Suggestions = append(result.Suggestions, "Add ownership section to documentation")
		}
	}

	// Calculate complexity based on imports and content
	data, err := os.ReadFile(path)
	if err == nil {
		content := string(data)
		lines := strings.Split(content, "\n")
		result.Complexity = len(lines)

		if len(lines) > 100 {
			result.Suggestions = append(result.Suggestions, "Consider splitting into smaller modules (over 100 lines)")
		}
	}

	// Extract cross-references from imports
	for _, imp := range info.Imports {
		if strings.HasPrefix(imp, "./") || strings.HasPrefix(imp, "../") {
			resolved := resolveImport(path, imp)
			if resolved != "" {
				result.CrossRefs = append(result.CrossRefs, resolved)
			}
		}
	}

	result.Dependencies = info.Imports

	return result
}

func AnalyzeRepository(modules []scanner.Module, parsed map[string]*parser.ModuleInfo) *DocMetrics {
	metrics := &DocMetrics{
		TotalModules: len(modules),
	}

	var totalQuality float64
	for _, m := range modules {
		if info, ok := parsed[m.Path]; ok {
			analysis := AnalyzeModule(m.Path, info)
			totalQuality += analysis.DocQuality
			if analysis.HasDocHeader {
				metrics.DocumentedModules++
			}
			metrics.TotalSuggestions += len(analysis.Suggestions)
		}
	}

	if len(modules) > 0 {
		metrics.AverageQuality = totalQuality / float64(len(modules))
		metrics.CoveragePercent = float64(metrics.DocumentedModules) / float64(len(modules)) * 100
	}

	return metrics
}

func GenerateDocReport(modules []scanner.Module, parsed map[string]*parser.ModuleInfo) string {
	var b strings.Builder

	b.WriteString("# Documentation Analysis Report\n\n")

	metrics := AnalyzeRepository(modules, parsed)
	b.WriteString("## Metrics\n\n")
	b.WriteString(fmt.Sprintf("- Total modules: %d\n", metrics.TotalModules))
	b.WriteString(fmt.Sprintf("- Documented modules: %d\n", metrics.DocumentedModules))
	b.WriteString(fmt.Sprintf("- Coverage: %.1f%%\n", metrics.CoveragePercent))
	b.WriteString(fmt.Sprintf("- Average quality: %.2f\n", metrics.AverageQuality))
	b.WriteString(fmt.Sprintf("- Total suggestions: %d\n\n", metrics.TotalSuggestions))

	type moduleAnalysis struct {
		path     string
		quality  float64
		suggests int
	}

	var analyses []moduleAnalysis
	for _, m := range modules {
		if info, ok := parsed[m.Path]; ok {
			a := AnalyzeModule(m.Path, info)
			analyses = append(analyses, moduleAnalysis{
				path:     m.RelPath,
				quality:  a.DocQuality,
				suggests: len(a.Suggestions),
			})
		}
	}

	sort.Slice(analyses, func(i, j int) bool {
		return analyses[i].quality < analyses[j].quality
	})

	b.WriteString("## Modules Needing Attention\n\n")
	count := 0
	for _, a := range analyses {
		if a.quality < 0.5 {
			b.WriteString(fmt.Sprintf("- **%s** (quality: %.2f, suggestions: %d)\n", a.path, a.quality, a.suggests))
			count++
			if count >= 10 {
				break
			}
		}
	}

	if count == 0 {
		b.WriteString("All modules have good documentation quality.\n")
	}

	return b.String()
}

func resolveImport(modulePath, imp string) string {
	dir := filepath.Dir(modulePath)
	resolved := filepath.Join(dir, imp)
	if !strings.HasSuffix(resolved, ".nix") {
		resolved += "/default.nix"
	}
	if _, err := os.Stat(resolved); err == nil {
		return resolved
	}
	return ""
}
