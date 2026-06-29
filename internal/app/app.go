package app

import (
	"github.com/willisivali/nixos-infrastructure/internal/config"
	"github.com/willisivali/nixos-infrastructure/internal/logger"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

type App struct {
	RootDir string
	Config  *config.Config
	Log     *logger.Logger
	Term    *terminal.Terminal
}

func levelFromString(s string) logger.Level {
	switch s {
	case "trace":
		return logger.Trace
	case "debug":
		return logger.Debug
	case "warn":
		return logger.Warn
	case "error":
		return logger.Error
	case "fatal":
		return logger.Fatal
	default:
		return logger.Info
	}
}

func New() (*App, error) {
	cfg, err := config.Load()
	if err != nil {
		return nil, err
	}

	log := logger.New(levelFromString(cfg.LogLevel))

	term := terminal.New(terminal.WithTheme(cfg.Theme))

	return &App{
		RootDir: ".",
		Config:  cfg,
		Log:     log,
		Term:    term,
	}, nil
}
