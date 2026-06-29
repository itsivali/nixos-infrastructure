package scanner

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type ModuleCategory string

const (
	CatNixOS      ModuleCategory = "nixos"
	CatHomeManager ModuleCategory = "home-manager"
	CatHost       ModuleCategory = "host"
	CatPackage    ModuleCategory = "package"
	CatLibrary    ModuleCategory = "library"
	CatConfig     ModuleCategory = "config"
	CatScript     ModuleCategory = "script"
	CatSecret     ModuleCategory = "secret"
	CatTest       ModuleCategory = "test"
)

type ModuleType string

const (
	TypeEntry    ModuleType = "entry"     // default.nix
	TypeOptions  ModuleType = "options"   // options.nix, *-options.nix
	TypeRegular  ModuleType = "regular"   // *.nix
	TypePrivate  ModuleType = "private"   // _*.nix
	TypeSubdir   ModuleType = "subdir"    // dir/default.nix
)

type Module struct {
	Path        string        `json:"path"`
	RelPath     string        `json:"rel_path"`
	Domain      string        `json:"domain"`
	Category    ModuleCategory `json:"category"`
	Type        ModuleType    `json:"type"`
	HasDefault  bool          `json:"has_default"`
	FileCount   int           `json:"file_count"`
	LineCount   int           `json:"line_count"`
	IsDir       bool          `json:"is_dir"`
	Submodules  []Module      `json:"submodules,omitempty"`
}

type Domain struct {
	Name     string   `json:"name"`
	Path     string   `json:"path"`
	RelPath  string   `json:"rel_path"`
	Category ModuleCategory `json:"category"`
	Modules  []Module `json:"modules"`
	FileCount int     `json:"file_count"`
}

type ScanResult struct {
	Root        string            `json:"root"`
	Domains     []Domain          `json:"domains"`
	AllModules  []Module          `json:"all_modules"`
	Hosts       []Module          `json:"hosts"`
	Packages    []Domain          `json:"packages"`
	HomeModules []Domain          `json:"home_modules"`
	LibModules  []Module          `json:"lib_modules"`
	ConfigFiles []Module          `json:"config_files"`
	Scripts     []Module          `json:"scripts"`
	Secrets     []Module          `json:"secrets"`
	Tests       []Module          `json:"tests"`
	TotalFiles  int               `json:"total_files"`
	TotalLines  int               `json:"total_lines"`
}

type Scanner struct {
	root     string
	excluded map[string]bool
}

func New(root string) *Scanner {
	return &Scanner{
		root: root,
		excluded: map[string]bool{
			".git":    true,
			"result":  true,
			".direnv": true,
			"node_modules": true,
		},
	}
}

func (s *Scanner) Scan() (*ScanResult, error) {
	result := &ScanResult{Root: s.root}

	entries, err := os.ReadDir(s.root)
	if err != nil {
		return nil, err
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			if strings.HasSuffix(entry.Name(), ".nix") {
				_, _ = entry.Info()
				lines := countLines(filepath.Join(s.root, entry.Name()))
				mod := Module{
					Path:   filepath.Join(s.root, entry.Name()),
					RelPath: entry.Name(),
					Type:   moduleType(entry.Name()),
					Category: configCategory(entry.Name()),
					LineCount: lines,
				}
				result.ConfigFiles = append(result.ConfigFiles, mod)
				result.AllModules = append(result.AllModules, mod)
				result.TotalFiles++
				result.TotalLines += lines
			}
			continue
		}

		name := entry.Name()
		if s.excluded[name] || strings.HasPrefix(name, "_") {
			continue
		}

		dirPath := filepath.Join(s.root, name)

		switch {
		case name == "home":
			domains := s.scanHomeManager(dirPath)
			result.HomeModules = domains
			for _, d := range domains {
				result.TotalFiles += d.FileCount
				result.AllModules = append(result.AllModules, d.Modules...)
			}

		case name == "hosts":
			mods := s.scanDir(dirPath, "hosts", CatHost, 0)
			result.Hosts = mods
			for _, m := range mods {
				result.TotalFiles++
				result.TotalLines += m.LineCount
				result.AllModules = append(result.AllModules, m)
			}

		case name == "packages":
			domains := s.scanPackageSets(dirPath)
			result.Packages = domains
			for _, d := range domains {
				result.TotalFiles += d.FileCount
				result.AllModules = append(result.AllModules, d.Modules...)
			}

		case name == "lib":
			mods := s.scanDir(dirPath, "lib", CatLibrary, 0)
			result.LibModules = mods
			for _, m := range mods {
				result.TotalFiles++
				result.TotalLines += m.LineCount
				result.AllModules = append(result.AllModules, m)
			}

		case name == "scripts":
			entries, _ := os.ReadDir(dirPath)
			for _, e := range entries {
				if !e.IsDir() && strings.HasSuffix(e.Name(), ".sh") {
					result.Scripts = append(result.Scripts, Module{
						Path:   filepath.Join(dirPath, e.Name()),
						RelPath: "scripts/" + e.Name(),
					})
				}
			}

		case name == "secrets":
			entries, _ := os.ReadDir(dirPath)
			for _, e := range entries {
				if !e.IsDir() {
					result.Secrets = append(result.Secrets, Module{
						Path:   filepath.Join(dirPath, e.Name()),
						RelPath: "secrets/" + e.Name(),
					})
				}
			}

		case name == "tests":
			mods := s.scanDir(dirPath, "tests", CatTest, 0)
			result.Tests = mods
			for _, m := range mods {
				result.TotalFiles++
				result.TotalLines += m.LineCount
				result.AllModules = append(result.AllModules, m)
			}

		default:
			// Check if it's a domain module (has default.nix)
			defaultPath := filepath.Join(dirPath, "default.nix")
			if _, err := os.Stat(defaultPath); err == nil {
				domain := s.scanDomain(dirPath, name)
				result.Domains = append(result.Domains, domain)
				result.TotalFiles += domain.FileCount
				result.AllModules = append(result.AllModules, domain.Modules...)
			}
		}
	}

	// Count total lines from all modules
	lineCount := 0
	for _, m := range result.AllModules {
		lineCount += m.LineCount
	}
	result.TotalLines = lineCount

	return result, nil
}

func (s *Scanner) scanDomain(dirPath, name string) Domain {
	domain := Domain{
		Name:     name,
		Path:     dirPath,
		RelPath:  name,
		Category: CatNixOS,
	}

	mods := s.scanDir(dirPath, name, CatNixOS, 1)
	domain.Modules = mods

	count := 0
	for _, m := range mods {
		count += m.LineCount
	}
	domain.FileCount = len(mods)

	return domain
}

func (s *Scanner) scanHomeManager(dirPath string) []Domain {
	var domains []Domain

	entries, _ := os.ReadDir(dirPath)

	for _, entry := range entries {
		if !entry.IsDir() || strings.HasPrefix(entry.Name(), "_") || entry.Name() == ".git" {
			continue
		}

		subPath := filepath.Join(dirPath, entry.Name())
		domain := Domain{
			Name:     entry.Name(),
			Path:     subPath,
			RelPath:  "home/" + entry.Name(),
			Category: CatHomeManager,
		}

		// Scan the HM domain with depth=1
		defaultPath := filepath.Join(subPath, "default.nix")
		if _, err := os.Stat(defaultPath); err == nil {
			mods := s.scanDir(subPath, "home/"+entry.Name(), CatHomeManager, 1)
			domain.Modules = mods
		} else {
			// Might be a flat module file (like fonts.nix)
			mods := s.scanLevel(subPath, "home/"+entry.Name(), CatHomeManager, true)
			domain.Modules = mods
		}

		domain.FileCount = len(domain.Modules)
		domains = append(domains, domain)
	}

	return domains
}

func (s *Scanner) scanPackageSets(dirPath string) []Domain {
	var domains []Domain

	entries, _ := os.ReadDir(dirPath)
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		pkgPath := filepath.Join(dirPath, entry.Name())
		domain := Domain{
			Name:     entry.Name(),
			Path:     pkgPath,
			RelPath:  "packages/" + entry.Name(),
			Category: CatPackage,
		}

		mods := s.scanLevel(pkgPath, "packages/"+entry.Name(), CatPackage, false)
		domain.Modules = mods
		domain.FileCount = len(mods)
		domains = append(domains, domain)
	}

	return domains
}

// scanDir scans a directory recursively, respecting auto-import rules.
// depth: 0 = scan files only (no subdirs), 1 = scan files + one level of subdirs, -1 = unlimited
func (s *Scanner) scanDir(dirPath, relPrefix string, category ModuleCategory, depth int) []Module {
	var modules []Module

	entries, err := os.ReadDir(dirPath)
	if err != nil {
		return nil
	}

	// Auto-import order: default.nix first, then options, then modules, then subdirs
	var defaultFile string
	var optionFiles, regularFiles, subdirs []string
	for _, entry := range entries {
		name := entry.Name()
		if strings.HasPrefix(name, "_") || s.excluded[name] {
			continue
		}

		if entry.IsDir() {
			defaultPath := filepath.Join(dirPath, name, "default.nix")
			if _, err := os.Stat(defaultPath); err == nil {
				subdirs = append(subdirs, name)
			}
		} else if strings.HasSuffix(name, ".nix") {
			if name == "default.nix" {
				defaultFile = name
			} else if name == "options.nix" || strings.HasSuffix(name, "-options.nix") {
				optionFiles = append(optionFiles, name)
			} else {
				regularFiles = append(regularFiles, name)
			}
		}
	}

	sort.Strings(optionFiles)
	sort.Strings(regularFiles)
	sort.Strings(subdirs)

	collectLines := func(files []string) []Module {
		var mods []Module
		for _, f := range files {
			fullPath := filepath.Join(dirPath, f)
			relPath := relPrefix + "/" + f
			lines := countLines(fullPath)
			mods = append(mods, Module{
				Path:      fullPath,
				RelPath:   relPath,
				Domain:    relPrefix,
				Category:  category,
				Type:      moduleType(f),
				LineCount: lines,
			})
		}
		return mods
	}

	if defaultFile != "" {
		modules = append(modules, collectLines([]string{defaultFile})...)
	}
	modules = append(modules, collectLines(optionFiles)...)
	modules = append(modules, collectLines(regularFiles)...)

	if depth != 0 {
		for _, sub := range subdirs {
			subPath := filepath.Join(dirPath, sub)
			subPrefix := relPrefix + "/" + sub
			subMods := s.scanDir(subPath, subPrefix, category, depth-1)
			modules = append(modules, subMods...)
		}
	}

	return modules
}

// scanLevel scans a single directory for .nix files (non-recursive, files only)
func (s *Scanner) scanLevel(dirPath, relPrefix string, category ModuleCategory, includeDefault bool) []Module {
	var modules []Module

	entries, err := os.ReadDir(dirPath)
	if err != nil {
		return nil
	}

	var files []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasSuffix(name, ".nix") {
			continue
		}
		if name == "default.nix" && !includeDefault {
			continue
		}
		files = append(files, name)
	}

	sort.Strings(files)

	for _, f := range files {
		fullPath := filepath.Join(dirPath, f)
		relPath := relPrefix + "/" + f
		lines := countLines(fullPath)
		modules = append(modules, Module{
			Path:      fullPath,
			RelPath:   relPath,
			Domain:    relPrefix,
			Category:  category,
			Type:      moduleType(f),
			LineCount: lines,
		})
	}

	return modules
}

func moduleType(name string) ModuleType {
	if name == "default.nix" {
		return TypeEntry
	}
	if strings.HasPrefix(name, "_") {
		return TypePrivate
	}
	if name == "options.nix" || strings.HasSuffix(name, "-options.nix") {
		return TypeOptions
	}
	return TypeRegular
}

func configCategory(name string) ModuleCategory {
	switch name {
	case "configuration.nix":
		return CatConfig
	case "flake.nix":
		return CatConfig
	default:
		return CatConfig
	}
}

func countLines(path string) int {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	count := 0
	for _, b := range data {
		if b == '\n' {
			count++
		}
	}
	return count
}
