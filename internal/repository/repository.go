package repository

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/adrg/xdg"
	"github.com/willisivali/nixos-infrastructure/internal/parser"
	"github.com/willisivali/nixos-infrastructure/internal/scanner"
)

type Repository struct {
	Root      string `json:"root"`
	ScanTime  time.Time `json:"scan_time"`
	FileHash  string `json:"file_hash"`

	Result    *scanner.ScanResult    `json:"-"`
	Parsed    map[string]*parser.ModuleInfo `json:"-"`

	mu        sync.RWMutex
	cached    bool
}

type RepoCache struct {
	Root     string    `json:"root"`
	ScanTime time.Time `json:"scan_time"`
	FileHash string    `json:"file_hash"`
	ScanJSON []byte    `json:"scan_json"`
	ParseMap map[string]*parser.ModuleInfo `json:"parse_map"`
}

func cacheDir() string {
	dir, err := xdg.CacheFile("ivali/repo-cache.json")
	if err != nil {
		return ""
	}
	return dir
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
			repo := &Repository{Root: candidate}
			if err := repo.loadCache(); err != nil {
				repo.cached = false
			}
			return repo, true
		}
		parent := filepath.Dir(candidate)
		if parent == candidate {
			break
		}
		candidate = parent
	}

	return nil, false
}

func (r *Repository) Scan() error {
	r.mu.Lock()
	defer r.mu.Unlock()

	hash := r.computeHash()
	if r.Result != nil && hash == r.FileHash {
		return nil
	}

	s := scanner.New(r.Root)
	result, err := s.Scan()
	if err != nil {
		return fmt.Errorf("scan repository: %w", err)
	}
	r.Result = result

	parsed := make(map[string]*parser.ModuleInfo)
	for _, m := range result.AllModules {
		if !strings.HasSuffix(m.Path, ".nix") {
			continue
		}
		info, err := parser.Parse(m.Path)
		if err != nil {
			continue
		}
		parsed[m.Path] = info
	}
	r.Parsed = parsed
	r.ScanTime = time.Now()
	r.FileHash = hash

	if err := r.saveCache(); err != nil {
		// Non-fatal: cache is optional
		_ = err
	}

	return nil
}

func (r *Repository) EnsureScanned() error {
	r.mu.RLock()
	if r.Result != nil {
		r.mu.RUnlock()
		return nil
	}
	r.mu.RUnlock()

	return r.Scan()
}

func (r *Repository) ModuleCount() (nixos int, hm int, total int) {
	if r.Result == nil {
		return 0, 0, 0
	}
	for _, m := range r.Result.AllModules {
		switch m.Category {
		case scanner.CatNixOS:
			nixos++
		case scanner.CatHomeManager:
			hm++
		}
	}
	return nixos, hm, len(r.Result.AllModules)
}

func (r *Repository) FileCount() int {
	if r.Result == nil {
		return 0
	}
	return r.Result.TotalFiles
}

func (r *Repository) DomainList() []string {
	if r.Result == nil {
		return nil
	}
	var names []string
	for _, d := range r.Result.Domains {
		names = append(names, d.Name)
	}
	sort.Strings(names)
	return names
}

func (r *Repository) HostList() []string {
	if r.Result == nil {
		return nil
	}
	var names []string
	for _, h := range r.Result.Hosts {
		name := strings.TrimSuffix(filepath.Base(h.Path), ".nix")
		names = append(names, name)
	}
	return names
}

func (r *Repository) PackageCount() int {
	if r.Result == nil {
		return 0
	}
	count := 0
	for _, p := range r.Result.Packages {
		count += len(p.Modules)
	}
	return count
}

func (r *Repository) FlakeInputs() int {
	flakePath := filepath.Join(r.Root, "flake.nix")
	data, err := os.ReadFile(flakePath)
	if err != nil {
		return 0
	}
	// Count "url =" lines in inputs
	count := 0
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.Contains(trimmed, "url") && strings.Contains(trimmed, "=") && !strings.HasPrefix(trimmed, "#") {
			count++
		}
	}
	return count
}

func (r *Repository) CheckDuplicateImports() []string {
	if r.Result == nil {
		return nil
	}
	seen := make(map[string]string)
	var duplicates []string
	for _, info := range r.Parsed {
		for _, imp := range info.Imports {
			if prev, ok := seen[imp]; ok {
				duplicates = append(duplicates, fmt.Sprintf("%s (in %s and %s)", imp, prev, info.RelPath))
			} else {
				seen[imp] = info.RelPath
			}
		}
	}
	return duplicates
}

func (r *Repository) CheckOrphanModules() []string {
	if r.Result == nil {
		return nil
	}

	// Build map of directories whose default.nix uses auto-imports
	autoImportDirs := make(map[string]bool)
	for _, info := range r.Parsed {
		if info.IsAutoImport {
			autoImportDirs[filepath.Dir(info.Path)] = true
		}
	}

	// Build map of explicitly imported files
	explicitlyImported := make(map[string]bool)
	for path, info := range r.Parsed {
		for _, imp := range info.Imports {
			if strings.HasPrefix(imp, "./") || strings.HasPrefix(imp, "../") {
				abs := filepath.Join(filepath.Dir(path), imp)
				explicitlyImported[abs] = true
			}
		}
	}

	var orphans []string
	for _, m := range r.Result.AllModules {
		if m.Type == scanner.TypeEntry || m.Type == scanner.TypePrivate {
			continue
		}
		if !strings.HasSuffix(m.Path, ".nix") {
			continue
		}

		moduleDir := filepath.Dir(m.Path)

		// Not orphan if parent dir uses auto-import
		if autoImportDirs[moduleDir] {
			continue
		}
		if autoImportDirs[filepath.Dir(moduleDir)] {
			continue
		}

		// Not orphan if explicitly imported by another module
		if explicitlyImported[m.Path] {
			continue
		}

		// Not orphan if it imports something (it's an importer, not orphan)
		if info := r.Parsed[m.Path]; info != nil && len(info.Imports) > 0 {
			continue
		}

		orphans = append(orphans, m.RelPath)
	}
	return orphans
}

func (r *Repository) HealthSummary() map[string]string {
	summary := make(map[string]string)

	if r.Result == nil {
		summary["status"] = "unknown"
		return summary
	}

	summary["modules"] = fmt.Sprintf("%d total", len(r.Result.AllModules))
	summary["domains"] = fmt.Sprintf("%d domains", len(r.Result.Domains))

	dups := r.CheckDuplicateImports()
	if len(dups) == 0 {
		summary["duplicates"] = "none"
	} else {
		summary["duplicates"] = fmt.Sprintf("%d found", len(dups))
	}

	orphans := r.CheckOrphanModules()
	if len(orphans) == 0 {
		summary["orphans"] = "none"
	} else {
		summary["orphans"] = fmt.Sprintf("%d found", len(orphans))
	}

	return summary
}

func (r *Repository) CheckMissingDocHeaders() []string {
	if r.Parsed == nil {
		return nil
	}
	var missing []string
	for _, info := range r.Parsed {
		if info.DocHeader == "" && !info.IsAutoImport {
			missing = append(missing, info.RelPath)
		}
	}
	sort.Strings(missing)
	return missing
}

func (r *Repository) CheckModulesWithOptions() []string {
	if r.Result == nil {
		return nil
	}
	var optMods []string
	for _, m := range r.Result.AllModules {
		if info, ok := r.Parsed[m.Path]; ok && info.HasOptions {
			optMods = append(optMods, m.RelPath)
		}
	}
	sort.Strings(optMods)
	return optMods
}

func (r *Repository) FindModule(query string) (scanner.Module, *parser.ModuleInfo, bool) {
	if r.Result == nil || r.Parsed == nil {
		return scanner.Module{}, nil, false
	}

	// Exact match on RelPath
	for _, m := range r.Result.AllModules {
		if m.RelPath == query || m.Path == query {
			if info, ok := r.Parsed[m.Path]; ok {
				return m, info, true
			}
			return m, nil, true
		}
	}

	// Partial match on RelPath (contains)
	for _, m := range r.Result.AllModules {
		if strings.Contains(m.RelPath, query) {
			if info, ok := r.Parsed[m.Path]; ok {
				return m, info, true
			}
			return m, nil, true
		}
	}

	return scanner.Module{}, nil, false
}

func (r *Repository) computeHash() string {
	files, _ := filepath.Glob(filepath.Join(r.Root, "**/*.nix"))
	if len(files) > 50 {
		files = files[:50]
	}
	var hash string
	for _, f := range files {
		info, err := os.Stat(f)
		if err != nil {
			continue
		}
		hash += fmt.Sprintf("%s:%d;", f, info.ModTime().UnixNano())
	}
	return hash
}

func (r *Repository) cachePath() string {
	dir := cacheDir()
	if dir == "" {
		return ""
	}
	return dir
}

func (r *Repository) loadCache() error {
	path := r.cachePath()
	if path == "" {
		return fmt.Errorf("no cache path")
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	var cache RepoCache
	if err := json.Unmarshal(data, &cache); err != nil {
		return err
	}

	if cache.Root != r.Root {
		return fmt.Errorf("cache root mismatch")
	}

	r.ScanTime = cache.ScanTime
	r.FileHash = cache.FileHash
	r.cached = true

	if len(cache.ScanJSON) > 0 {
		var result scanner.ScanResult
		if err := json.Unmarshal(cache.ScanJSON, &result); err == nil {
			r.Result = &result
		}
	}

	if cache.ParseMap != nil {
		r.Parsed = cache.ParseMap
	}

	return nil
}

func (r *Repository) saveCache() error {
	path := r.cachePath()
	if path == "" {
		return fmt.Errorf("no cache path")
	}

	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("create cache dir: %w", err)
	}

	scanJSON, err := json.Marshal(r.Result)
	if err != nil {
		return fmt.Errorf("marshal scan result: %w", err)
	}

	cache := RepoCache{
		Root:     r.Root,
		ScanTime: r.ScanTime,
		FileHash: r.FileHash,
		ScanJSON: scanJSON,
		ParseMap: r.Parsed,
	}

	data, err := json.Marshal(cache)
	if err != nil {
		return fmt.Errorf("marshal cache: %w", err)
	}

	return os.WriteFile(path, data, 0o644)
}
