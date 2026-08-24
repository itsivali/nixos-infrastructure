package app

import (
	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/plugin"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

func (a *App) InitPlugins() {
	if a.State == nil {
		a.State = state.New()
	}
	if a.Events == nil {
		a.Events = events.New()
	}

	a.Plugins = plugin.NewRegistry(a.State, a.Events)

	seedPlugins := []plugin.Plugin{
		plugin.NewBitwardenPlugin(),
		plugin.NewSecurityPlugin(),
		plugin.NewGitOpsPlugin(a.RootDir),
		plugin.NewObservabilityPlugin(),
		plugin.NewRecoveryPlugin(),
		plugin.NewDesktopPlugin(),
		plugin.NewDeveloperPlugin(),
		plugin.NewAIPlugin(),
	}

	for _, p := range seedPlugins {
		if err := a.Plugins.Register(p); err != nil {
			a.Log.Warn().Err(err).Msgf("plugin registration: %s", p.Name())
		}
	}

	if errs := a.Plugins.InitAll(); len(errs) > 0 {
		for _, err := range errs {
			a.Log.Warn().Err(err).Msg("plugin init")
		}
	}
}
