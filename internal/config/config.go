package config

import (
	"os"

	"github.com/BurntSushi/toml"
	"github.com/adrg/xdg"
)

type Config struct {
	Theme    string `toml:"theme"`
	LogLevel string `toml:"log_level"`
	Cache    Cache  `toml:"cache"`
	Doctor   Doctor `toml:"doctor"`
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

	paths := []string{
		"ivali.toml",
	}

	if configDir, err := xdg.ConfigFile("ivali/config.toml"); err == nil {
		paths = append(paths, configDir)
	}

	for _, path := range paths {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		if err := toml.Unmarshal(data, cfg); err != nil {
			return nil, err
		}
	}

	return cfg, nil
}

func (c *Config) Save(path string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return toml.NewEncoder(f).Encode(c)
}
