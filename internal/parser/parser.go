package parser

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type ModuleInfo struct {
	Path        string   `json:"path"`
	RelPath     string   `json:"rel_path"`
	DocHeader   string   `json:"doc_header,omitempty"`
	Purpose     string   `json:"purpose,omitempty"`
	Owns        []string `json:"owns,omitempty"`
	Imports     []string `json:"imports,omitempty"`
	HasOptions  bool     `json:"has_options"`
	IsAutoImport bool    `json:"is_auto_import"`
}

var (
	autoImportRe  = regexp.MustCompile(`import\s+(?:\.\./)*lib/auto-imports\.nix`)
	optionDeclRe  = regexp.MustCompile(`options\s*=\s*\{`)
	commentBlockRe = regexp.MustCompile(`(?s)#{3,}.*?#{3,}`)
	purposeRe     = regexp.MustCompile(`(?i)Purpose\s*\n\s*-+\s*\n\s*(.+?)(?:\n\n|\n#|\z)`)
	ownsRe        = regexp.MustCompile(`(?i)(?:Owns?|Ownership)\s*\n\s*-+\s*\n\s*(.+?)(?:\n\n|\n#|\z)`)
)

func Parse(path string) (*ModuleInfo, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	content := string(data)

	info := &ModuleInfo{
		Path:    path,
		RelPath: relPath(path),
	}

	info.DocHeader = extractDocHeader(content)
	info.Purpose = extractPurpose(content, info.DocHeader)
	info.Owns = extractOwns(content, info.DocHeader)
	info.Imports = extractImports(content)
	info.HasOptions = optionDeclRe.MatchString(content)
	info.IsAutoImport = autoImportRe.MatchString(content)

	return info, nil
}

func extractDocHeader(content string) string {
	matches := commentBlockRe.FindString(content)
	if matches == "" {
		return ""
	}

	lines := strings.Split(matches, "\n")
	var cleaned []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		trimmed = strings.TrimPrefix(trimmed, "#")
		trimmed = strings.TrimSpace(trimmed)
		if trimmed != "" {
			cleaned = append(cleaned, trimmed)
		}
	}
	return strings.Join(cleaned, "\n")
}

func extractPurpose(content, header string) string {
	if header != "" {
		matches := purposeRe.FindStringSubmatch(header)
		if len(matches) > 1 {
			return strings.TrimSpace(matches[1])
		}
	}
	matches := purposeRe.FindStringSubmatch(content)
	if len(matches) > 1 {
		return strings.TrimSpace(matches[1])
	}
	return ""
}

func extractOwns(content, header string) []string {
	var owns []string

	source := header
	if source == "" {
		source = content
	}

	matches := ownsRe.FindStringSubmatch(source)
	if len(matches) > 1 {
		lines := strings.Split(matches[1], "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			line = strings.TrimLeft(line, "- ")
			line = strings.TrimSpace(line)
			if line != "" && !strings.HasPrefix(line, "-") {
				owns = append(owns, line)
			}
		}
	}

	return owns
}

func extractImports(content string) []string {
	var imports []string

	// Detect auto-import (e.g. imports = import ../lib/auto-imports.nix ./.;)
	if autoImportRe.MatchString(content) {
		imports = append(imports, "<auto-imports>")
	}

	inBlock := false
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)

		if !inBlock {
			if !strings.HasPrefix(trimmed, "imports") || !strings.Contains(trimmed, "=") {
				continue
			}
			// Single-line block: imports = [ ./foo.nix ./bar.nix ];
			if strings.Contains(trimmed, "[") && strings.Contains(trimmed, "]") {
				extractInlineImports(trimmed, &imports)
				continue
			}
			// Multi-line block: imports = [\n  ...
			if strings.Contains(trimmed, "[") {
				inBlock = true
			}
			continue
		}

		// Inside a multi-line import block
		idx := strings.Index(trimmed, "]")
		if idx >= 0 {
			// Extract everything before the closing bracket
			before := strings.TrimSpace(trimmed[:idx])
			if before != "" && !strings.HasPrefix(before, "#") && !strings.HasPrefix(before, "//") {
				clean := strings.TrimRight(before, ";,")
				clean = strings.TrimSpace(clean)
				if clean != "" {
					imports = append(imports, clean)
				}
			}
			inBlock = false
			continue
		}

		if strings.HasPrefix(trimmed, "#") || trimmed == "" || strings.HasPrefix(trimmed, "//") {
			continue
		}
		clean := strings.TrimRight(trimmed, ";,")
		clean = strings.TrimSpace(clean)
		if clean != "" {
			imports = append(imports, clean)
		}
	}

	return imports
}

func extractInlineImports(line string, imports *[]string) {
	start := strings.Index(line, "[")
	end := strings.Index(line, "]")
	if start < 0 || end < 0 || end <= start {
		return
	}
	inner := line[start+1 : end]
	parts := strings.Fields(inner)
	for _, p := range parts {
		p = strings.TrimRight(p, ";,")
		p = strings.TrimSpace(p)
		if p != "" {
			*imports = append(*imports, p)
		}
	}
}

func relPath(path string) string {
	wd, _ := os.Getwd()
	rel, err := filepath.Rel(wd, path)
	if err != nil {
		return path
	}
	return rel
}
