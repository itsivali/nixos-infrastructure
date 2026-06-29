package template

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type Generator struct {
	Root string
}

type FileSpec struct {
	Path    string
	Content string
}

func New(root string) *Generator {
	return &Generator{Root: root}
}

func (g *Generator) Write(files []FileSpec) error {
	for _, f := range files {
		path := filepath.Join(g.Root, f.Path)
		dir := filepath.Dir(path)
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return fmt.Errorf("create dir %s: %w", dir, err)
		}
		if err := os.WriteFile(path, []byte(f.Content), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", f.Path, err)
		}
	}
	return nil
}

func sanitizeName(name string) string {
	name = strings.ToLower(name)
	name = strings.ReplaceAll(name, " ", "-")
	return name
}

func capitalize(s string) string {
	if s == "" {
		return ""
	}
	return strings.ToUpper(s[:1]) + s[1:]
}
