package app

import (
	"os"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/config"
	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/logger"
	"github.com/itsivali/nixos-infrastructure/internal/metrics"
	"github.com/itsivali/nixos-infrastructure/internal/monitor"
	"github.com/itsivali/nixos-infrastructure/internal/plugin"
	"github.com/itsivali/nixos-infrastructure/internal/remediation"
	"github.com/itsivali/nixos-infrastructure/internal/repository"
	"github.com/itsivali/nixos-infrastructure/internal/state"
	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

type InitLevel int

const (
	InitMinimal  InitLevel = 0
	InitStandard InitLevel = 1
	InitFull     InitLevel = 2
)

type App struct {
	RootDir     string
	Config      *config.Config
	Log         *logger.Logger
	Term        *terminal.Terminal
	State       *state.Engine
	Events      *events.Bus
	Plugins     *plugin.Registry
	Repo        *repository.Repository
	Metrics     *metrics.Collector
	Remediation *remediation.Engine
	Monitor     *monitor.Monitor
	InitLevel   InitLevel
	JSONOutput  bool
	Verbose     bool
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

	if level >= InitStandard {
		a.State = state.New()
		a.Events = events.New()
		a.Metrics = metrics.NewCollector(metrics.DefaultRegistry)

		a.Remediation = remediation.NewEngine(a.State, a.Events)
		a.Remediation.RegisterAction(remediation.NewServiceRestartAction())
		a.Remediation.RegisterAction(remediation.NewDiskCleanupAction())
		a.Remediation.RegisterAction(remediation.NewNetworkResetAction())
	a.Remediation.RegisterAction(remediation.NewNixOSRebuildAction())

		a.Monitor = monitor.New(a.State, a.Events, 30*time.Second)
		a.Monitor.RegisterCheck("disk", monitor.CheckDisk)
		a.Monitor.RegisterCheck("memory", monitor.CheckMemory)
		a.Monitor.RegisterCheck("load", monitor.CheckLoad)
		a.Monitor.RegisterCheck("sshd", monitor.CheckService("sshd"))
		a.Monitor.RegisterCheck("NetworkManager", monitor.CheckService("NetworkManager"))
		a.Monitor.RegisterCheck("tailscaled", monitor.CheckService("tailscaled"))
	}

	if level >= InitFull {
		a.detectRepo()
		a.InitPlugins()
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
