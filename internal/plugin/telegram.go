package plugin

import (
	"os"
	"os/exec"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/events"
	"github.com/itsivali/nixos-infrastructure/internal/state"
)

const TelegramPluginName = "telegram"

type TelegramPlugin struct {
	BasePlugin
}

func NewTelegramPlugin() *TelegramPlugin {
	return &TelegramPlugin{
		BasePlugin: NewBase("Telegram Bot"),
	}
}

func (p *TelegramPlugin) Name() string { return TelegramPluginName }

func (p *TelegramPlugin) Init(engine *state.Engine, bus *events.Bus) error {
	engine.SetDetail(p.Name(), state.WithVersion("1.0.0"))
	return nil
}

func (p *TelegramPlugin) Status() *state.ComponentStatus {
	meta := make(map[string]string)

	botToken := os.Getenv("BOT_TOKEN")
	if botToken == "" {
		if data, err := os.ReadFile("/run/secrets/telegram_bot_token"); err == nil {
			botToken = strings.TrimSpace(string(data))
		}
	}
	if botToken != "" {
		meta["token"] = "configured"
	} else {
		meta["token"] = "not configured"
	}

	stateVal := state.StateHealthy
	message := "bot configured"

	svcActive := false
	if out, err := exec.Command("systemctl", "is-active", "ivali-bot-go.service").Output(); err == nil {
		svcActive = strings.TrimSpace(string(out)) == "active"
	}
	meta["service"] = fmtBool(svcActive)

	if !svcActive {
		stateVal = state.StateWarning
		message = "bot service not running"
	}

	if botToken == "" {
		stateVal = state.StateDegraded
		message = "bot token not configured"
	}

	return &state.ComponentStatus{
		Name:     p.Name(),
		State:    stateVal,
		Message:  message,
		Metadata: meta,
	}
}

func (p *TelegramPlugin) Shutdown() error { return nil }
