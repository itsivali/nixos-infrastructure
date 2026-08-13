package handlers_test

import (
	"context"
	"strings"
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/handlers"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type dummyLogger struct{}

func (d *dummyLogger) Info(msg string, args ...any)  {}
func (d *dummyLogger) Error(msg string, args ...any) {}
func (d *dummyLogger) Debug(msg string, args ...any) {}

func setupTestBot() (*telegram.Bot, *services.Container) {
	api := telegram.NewAPI("fake-token")
	auth := telegram.NewAuth("/tmp")
	logger := &dummyLogger{}
	bot := telegram.New(api, auth, logger)

	svc := services.NewContainer("/tmp")

	// Register all production commands
	bot.RegisterCommands(
		handlers.NewHelpCommand(bot),
		handlers.NewStatusCommand(api, svc),
		handlers.NewHealthCommand(api, svc),
		handlers.NewDiskCommand(api, svc),
		handlers.NewProcessesCommand(api, svc),
		handlers.NewGenerationsCommand(api, svc),
		handlers.NewRebootCommand(api),
		handlers.NewShutdownCommand(api),
		handlers.NewDeployCommand(api, &telegram.Config{RepoDir: "/tmp"}, svc),
		handlers.NewRollbackCommand(api, svc),
		handlers.NewUpdateCommand(api, svc),
		handlers.NewScanCommand(api, svc),
		handlers.NewSecurityCommand(api, svc),
		handlers.NewDoctorCommand(api, svc),
		handlers.NewStoreCommand(api, svc),
		handlers.NewGCCommand(api, svc),
		handlers.NewAppsCommand(api, svc),
		handlers.NewOpenCommand(api, svc),
		handlers.NewVolumeCommand(api, svc),
		handlers.NewMuteCommand(api, svc),
		handlers.NewUnmuteCommand(api, svc),
		handlers.NewBrightnessCommand(api, svc),
		handlers.NewScreenshotCommand(api, svc),
		handlers.NewClipboardCommand(api, svc),
		handlers.NewDesktopPowerCommand(api, svc),
		handlers.NewFirefoxCommand(api, svc),
		handlers.NewWindowsCommand(api, svc),
		handlers.NewWorkspaceCommand(api, svc),
		handlers.NewGitCommand(api, svc),
		handlers.NewGithubCommand(api, svc),
		handlers.NewGitlabCommand(api, svc),
		handlers.NewNixCommand(api, svc),
		handlers.NewRunCommand(api, svc),
		handlers.NewPkgCommand(api, svc),
		handlers.NewSpeedtestCommand(api, svc),
		handlers.NewTopCommand(api, svc),
		handlers.NewLogCommand(api, svc),
		handlers.NewMetricsCommand(api, svc),
		handlers.NewUsersCommand(api, svc),
		handlers.NewAddUserCommand(api),
		handlers.NewRmUserCommand(api),
		handlers.NewMenuCommand(api),
		handlers.NewStartCommand(api),
		handlers.NewNotifyCommand(api, svc),
		handlers.NewMonitorOnCommand(api, svc),
		handlers.NewAuthStatusCommand(auth, api),
		handlers.NewGrantCommand(auth, api),
		handlers.NewRevokeCommand(auth, api),
		handlers.NewUsersListCommand(auth, api),
		handlers.NewMenuInlineCommand(api, svc),
		handlers.NewUptimeCommand(api, svc),
		handlers.NewMemoryCommand(api, svc),
		handlers.NewCPUCommand(api, svc),
		handlers.NewUpdatesCommand(api, svc),
		handlers.NewDiffCommand(api, svc),
		handlers.NewGitopsReconcileCommand(api, svc),
		handlers.NewVerifyCommand(api, svc),
		handlers.NewGitopsBackupCommand(api, svc),
		handlers.NewRestoreCommand(api, svc),
		handlers.NewTailscaleCommand(api, svc),
		handlers.NewFirewallCommand(api, svc),
		handlers.NewStateCommand(api, svc),
		handlers.NewEventsCommand(api, svc),
		handlers.NewPluginsCommand(api, svc),
		handlers.NewInventoryCommand(api, svc),
		handlers.NewAICommand(api, svc),
		handlers.NewOpenCodeCommand(api, svc),
		handlers.NewNetworkCommand(api, svc),
		handlers.NewJournalCommand(api, svc),
		handlers.NewRepoCommand(api, svc),
		handlers.NewSearchCommand(api, svc),
		handlers.NewGraphCommand(api, svc),
		handlers.NewSuggestCommand(api, svc),
	)

	cmdHandler := handlers.NewCmdCallbackHandler(bot)
	menuInline := handlers.NewMenuInlineCommand(api, svc)
	bot.RegisterCallback("menu:", menuInline)
	bot.RegisterCallback("cmd:", cmdHandler)

	return bot, svc
}

func TestCommandRegistrationIntegrity(t *testing.T) {
	bot, _ := setupTestBot()
	cmds := bot.GetCommands()

	if len(cmds) == 0 {
		t.Fatal("No commands registered in bot")
	}

	for _, cmd := range cmds {
		if strings.TrimSpace(cmd.Name()) == "" {
			t.Errorf("Command has empty name: %#v", cmd)
		}
		if strings.TrimSpace(cmd.Description()) == "" {
			t.Errorf("Command %s has empty description", cmd.Name())
		}
		foundCmd, ok := bot.CommandByName(cmd.Name())
		if !ok || foundCmd != cmd {
			t.Errorf("CommandByName failed for %s", cmd.Name())
		}
	}
}

func TestCallbackHandlerResolution(t *testing.T) {
	bot, svc := setupTestBot()
	menuInline := handlers.NewMenuInlineCommand(bot.API(), svc)
	cmdHandler := handlers.NewCmdCallbackHandler(bot)

	// List of known menu categories
	categories := []string{
		"system", "gitops", "security", "tailscale", "monitoring",
		"backup", "services", "desktop", "ai", "repository",
		"firewall", "recovery", "help",
	}

	for _, cat := range categories {
		msg := &telegram.Message{
			ChatID:          12345,
			UserID:          12345,
			IsCallback:      true,
			CallbackPayload: "menu:" + cat,
			CallbackID:      "cb-" + cat,
		}
		_ = menuInline.Execute(context.Background(), msg)
	}

	// Test generic callback handler with representative commands
	testCallbacks := []string{
		"cmd:top", "cmd:memory", "cmd:cpu", "cmd:deploy", "cmd:rollback",
		"cmd:diff", "cmd:security", "cmd:metrics", "cmd:backup_now",
		"cmd:restore", "cmd:journal", "cmd:opencode", "cmd:search",
	}

	for _, cbData := range testCallbacks {
		cmdName := strings.TrimPrefix(cbData, "cmd:")
		_, ok := bot.CommandByName(cmdName)
		if !ok {
			t.Errorf("Callback target '%s' is not a registered bot command", cmdName)
		}

		_ = cmdHandler.HandleCallback(context.Background(), "cb-123", 12345, 12345, cbData, 1)
	}
}
