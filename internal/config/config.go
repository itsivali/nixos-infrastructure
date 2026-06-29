package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
	"github.com/adrg/xdg"
)

type Config struct {
	Theme    string   `toml:"theme"`
	LogLevel string   `toml:"log_level"`
	Cache    Cache    `toml:"cache"`
	Doctor   Doctor   `toml:"doctor"`
	Exclude  []string `toml:"exclude"`
}

type Cache struct {
	Enabled bool `toml:"enabled"`
	TTL     int  `toml:"ttl"`
}

type Doctor struct {
	Skip []string `toml:"skip"`
}

func Default() *Config {
	return &Config{
		Theme:    "auto",
		LogLevel: "info",
		Cache: Cache{
			Enabled: true,
			TTL:     300,
		},
		Doctor: Doctor{
			Skip: []string{},
		},
		Exclude: []string{".git", "result", ".direnv"},
	}
}

func Load() (*Config, error) {
	cfg := Default()

	type configSource struct {
		path string
		kind string
	}

	var sources []configSource

	cwd, err := os.Getwd()
	if err == nil {
		project := filepath.Join(cwd, "ivali.toml")
		sources = append(sources, configSource{path: project, kind: "project"})
	}

	if configDir, err := xdg.ConfigFile("ivali/config.toml"); err == nil {
		sources = append(sources, configSource{path: configDir, kind: "user"})
	}

	for _, src := range sources {
		data, err := os.ReadFile(src.path)
		if err != nil {
			continue
		}
		if err := toml.Unmarshal(data, cfg); err != nil {
			return nil, fmt.Errorf("%s config %s: %w", src.kind, src.path, err)
		}
	}

	if err := cfg.validate(); err != nil {
		return nil, fmt.Errorf("config validation: %w", err)
	}

	return cfg, nil
}

func (c *Config) validate() error {
	validThemes := map[string]bool{
		"auto":  true,
		"light": true,
		"dark":  true,
	}
	if !validThemes[c.Theme] {
		return fmt.Errorf("invalid theme %q: must be auto, light, or dark", c.Theme)
	}

	validLevels := map[string]bool{
		"trace":   true,
		"debug":   true,
		"verbose": true,
		"info":    true,
		"warn":    true,
		"error":   true,
		"fatal":   true,
	}
	if !validLevels[strings.ToLower(c.LogLevel)] {
		return fmt.Errorf("invalid log_level %q: must be one of trace, debug, verbose, info, warn, error, fatal", c.LogLevel)
	}

	if c.Cache.TTL < 0 {
		return fmt.Errorf("cache.ttl must be >= 0, got %d", c.Cache.TTL)
	}

	return nil
}

func (c *Config) Save(path string) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}

	f, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("create config file: %w", err)
	}
	defer f.Close()

	return toml.NewEncoder(f).Encode(c)
}
