package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/BurntSushi/toml"
)

func TestDefault(t *testing.T) {
	cfg := Default()

	if cfg.Theme != "auto" {
		t.Errorf("expected theme 'auto', got %q", cfg.Theme)
	}
	if cfg.LogLevel != "info" {
		t.Errorf("expected log_level 'info', got %q", cfg.LogLevel)
	}
	if !cfg.Cache.Enabled {
		t.Error("expected cache.enabled to be true")
	}
	if cfg.Cache.TTL != 300 {
		t.Errorf("expected cache.ttl 300, got %d", cfg.Cache.TTL)
	}
}

func TestValidate(t *testing.T) {
	tests := []struct {
		name    string
		cfg     *Config
		wantErr bool
	}{
		{
			name:    "valid default",
			cfg:     Default(),
			wantErr: false,
		},
		{
			name: "valid dark theme",
			cfg: &Config{
				Theme:    "dark",
				LogLevel: "info",
				Cache:    Cache{TTL: 100},
			},
			wantErr: false,
		},
		{
			name: "invalid theme",
			cfg: &Config{
				Theme:    "neon",
				LogLevel: "info",
				Cache:    Cache{TTL: 100},
			},
			wantErr: true,
		},
		{
			name: "invalid log level",
			cfg: &Config{
				Theme:    "auto",
				LogLevel: "verbosee",
				Cache:    Cache{TTL: 100},
			},
			wantErr: true,
		},
		{
			name: "negative cache ttl",
			cfg: &Config{
				Theme:    "auto",
				LogLevel: "info",
				Cache:    Cache{TTL: -1},
			},
			wantErr: true,
		},
		{
			name: "valid warn level",
			cfg: &Config{
				Theme:    "auto",
				LogLevel: "warn",
				Cache:    Cache{TTL: 0},
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.cfg.validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestSaveAndLoad(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.toml")

	cfg := &Config{
		Theme:    "dark",
		LogLevel: "debug",
		Cache: Cache{
			Enabled: false,
			TTL:     600,
		},
		Doctor: Doctor{
			Skip: []string{"formatting"},
		},
		Exclude: []string{".git", "result"},
	}

	if err := cfg.Save(path); err != nil {
		t.Fatalf("Save() error = %v", err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("ReadFile() error = %v", err)
	}

	loaded := Default()
	if err := toml.Unmarshal(data, loaded); err != nil {
		t.Fatalf("toml.Unmarshal() error = %v", err)
	}

	if loaded.Theme != "dark" {
		t.Errorf("expected theme 'dark', got %q", loaded.Theme)
	}
	if loaded.LogLevel != "debug" {
		t.Errorf("expected log_level 'debug', got %q", loaded.LogLevel)
	}
	if loaded.Cache.Enabled {
		t.Error("expected cache.enabled to be false")
	}
	if loaded.Cache.TTL != 600 {
		t.Errorf("expected cache.ttl 600, got %d", loaded.Cache.TTL)
	}
}

func TestLoadNoFiles(t *testing.T) {
	cfg := Default()
	if err := cfg.validate(); err != nil {
		t.Errorf("Default() config failed validation: %v", err)
	}
}

func TestAllLogLevels(t *testing.T) {
	levels := []string{"trace", "debug", "verbose", "info", "warn", "error", "fatal"}
	for _, level := range levels {
		cfg := &Config{
			Theme:    "auto",
			LogLevel: level,
			Cache:    Cache{TTL: 100},
		}
		if err := cfg.validate(); err != nil {
			t.Errorf("log_level %q failed validation: %v", level, err)
		}
	}
}

func TestAllThemes(t *testing.T) {
	themes := []string{"auto", "light", "dark"}
	for _, theme := range themes {
		cfg := &Config{
			Theme:    theme,
			LogLevel: "info",
			Cache:    Cache{TTL: 100},
		}
		if err := cfg.validate(); err != nil {
			t.Errorf("theme %q failed validation: %v", theme, err)
		}
	}
}
