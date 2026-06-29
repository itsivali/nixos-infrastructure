package app

import (
	"os"

	"github.com/willisivali/nixos-infrastructure/internal/config"
	"github.com/willisivali/nixos-infrastructure/internal/logger"
	"github.com/willisivali/nixos-infrastructure/internal/repository"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

type InitLevel int

const (
	InitMinimal  InitLevel = 0
	InitStandard InitLevel = 1
	InitFull     InitLevel = 2
)

type App struct {
	RootDir    string
	Config     *config.Config
	Log        *logger.Logger
	Term       *terminal.Terminal
	Repo       *repository.Repository
	InitLevel  InitLevel
	JSONOutput bool
	Verbose    bool
}

func New(level InitLevel) (*App, error) {
	a := &App{
		InitLevel: level,
		RootDir:   ".",
	}

	cfg, err := config.Load()
	if err != nil {
		return nil, err
	}
	a.Config = cfg

	logLevel := logger.ParseLevel(cfg.LogLevel)
	caller := cfg.LogLevel == "trace"
	a.Log = logger.New(logLevel, logger.WithCaller(caller))

	termTheme := cfg.Theme
	if termTheme == "auto" {
		if os.Getenv("IVALI_THEME") != "" {
			termTheme = os.Getenv("IVALI_THEME")
		}
	}
	a.Term = terminal.New(terminal.WithTheme(termTheme))

	if level >= InitFull {
		a.detectRepo()
	}

	return a, nil
}

func (a *App) detectRepo() {
	if a.Repo != nil {
		return
	}
	if repo, found := repository.Detect("."); found {
		a.Repo = repo
		a.RootDir = repo.Root
	}
}

func (a *App) SetVerbose(v bool) {
	a.Verbose = v
	if v {
		a.Log.SetLevel(logger.Verbose)
	}
}

func (a *App) SetJSON(j bool) {
	a.JSONOutput = j
}

func (a *App) HasRepo() bool {
	a.detectRepo()
	return a.Repo != nil
}

func (a *App) RequireRepo() bool {
	a.detectRepo()
	if a.Repo == nil {
		a.Log.Debug().Msg("no repository detected")
		return false
	}
	return true
}

func (a *App) EnsureScanned() error {
	if a.Repo == nil {
		return nil
	}
	return a.Repo.EnsureScanned()
}
