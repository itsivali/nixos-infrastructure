package architecture

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// DomainManifest represents the domains.yaml file.
type DomainManifest struct {
	Domains map[string]Domain `yaml:"domains"`
}

// Domain represents a single architectural domain.
type Domain struct {
	Name                  string   `yaml:"-"`
	Level                 int      `yaml:"level"`
	Paths                 []string `yaml:"paths"`
	Public                []string `yaml:"public"`
	Internal              []string `yaml:"internal"`
	AllowedDependencies   []string `yaml:"allowed_dependencies"`
	ForbiddenDependencies []string `yaml:"forbidden_dependencies"`
}

// ExceptionManifest represents the exceptions.yaml file.
type ExceptionManifest struct {
	Exceptions []Exception `yaml:"exceptions"`
}

// Exception represents a documented architectural exception.
type Exception struct {
	ID     string `yaml:"id"`
	Source string `yaml:"source"`
	Target string `yaml:"target"`
	Reason string `yaml:"reason"`
	Owner  string `yaml:"owner"`
	Review string `yaml:"review"`
	Status string `yaml:"status"`
}

// DependenciesManifest represents the dependencies.yaml file.
type DependenciesManifest struct {
	NixImports           []DependencyEntry `yaml:"nix_imports"`
	ScriptReferences     []DependencyEntry `yaml:"script_references"`
	SOPSReferences       []DependencyEntry `yaml:"sops_references"`
	OptionNamespaceReads []OptionRead      `yaml:"option_namespace_reads"`
	FilesystemAccess     []FilesystemEntry `yaml:"filesystem_access"`
	CrossServiceState    []StateEntry      `yaml:"cross_service_state"`
}

// DependencyEntry is a single dependency relationship.
type DependencyEntry struct {
	Source   string   `yaml:"source"`
	Target   string   `yaml:"target"`
	Type     string   `yaml:"type"`
	Severity Severity `yaml:"severity"`
}

// OptionRead is a cross-domain option namespace read.
type OptionRead struct {
	Source   string   `yaml:"source"`
	Target   string   `yaml:"target"`
	Option   string   `yaml:"option"`
	Severity Severity `yaml:"severity"`
}

// FilesystemEntry is a cross-domain filesystem access record.
type FilesystemEntry struct {
	Source   string   `yaml:"source"`
	Target   string   `yaml:"target"`
	Access   string   `yaml:"access"`
	Owner    string   `yaml:"owner"`
	Severity Severity `yaml:"severity"`
}

// StateEntry is a cross-service state mutation record.
type StateEntry struct {
	Source   string   `yaml:"source"`
	Target   string   `yaml:"target"`
	Access   string   `yaml:"access"`
	Owner    string   `yaml:"owner"`
	Severity Severity `yaml:"severity"`
}

func (l *Linter) loadDomains(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("reading %s: %w", path, err)
	}

	var manifest DomainManifest
	if err := yaml.Unmarshal(data, &manifest); err != nil {
		return fmt.Errorf("parsing %s: %w", path, err)
	}

	// Set the Name field from the map key.
	for name, domain := range manifest.Domains {
		domain.Name = name
		manifest.Domains[name] = domain
	}

	l.Domains = &manifest
	return nil
}

func (l *Linter) loadExceptions(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			l.Exceptions = &ExceptionManifest{}
			return nil
		}
		return fmt.Errorf("reading %s: %w", path, err)
	}

	var manifest ExceptionManifest
	if err := yaml.Unmarshal(data, &manifest); err != nil {
		return fmt.Errorf("parsing %s: %w", path, err)
	}

	l.Exceptions = &manifest
	return nil
}

// loadDependencies loads the dependencies.yaml manifest.
func (l *Linter) loadDependencies(path string) (*DependenciesManifest, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading %s: %w", path, err)
	}

	var manifest DependenciesManifest
	if err := yaml.Unmarshal(data, &manifest); err != nil {
		return nil, fmt.Errorf("parsing %s: %w", path, err)
	}

	return &manifest, nil
}
