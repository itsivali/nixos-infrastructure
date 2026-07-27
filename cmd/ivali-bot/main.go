package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/metrics"
	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/handlers"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

func main() {
	debug := flag.Bool("debug", false, "Enable debug logging")
	flag.Parse()

	config, err := telegram.LoadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load config: %v\n", err)
		os.Exit(1)
	}
	config.Debug = *debug

	logger := telegram.NewSimpleLogger(config.Debug)
	runner := telegram.NewRunner(config, logger)
	bot := runner.Bot()

	// Create the shared services container.
	svc := services.NewContainer(config.RepoDir)

	// Register all commands using the shared services.
	bot.RegisterCommands(
		handlers.NewHelpCommand(bot),
		handlers.NewStatusCommand(bot.API(), svc),
		handlers.NewHealthCommand(bot.API(), svc),
		handlers.NewDiskCommand(bot.API(), svc),
		handlers.NewProcessesCommand(bot.API(), svc),
		handlers.NewGenerationsCommand(bot.API(), svc),
		handlers.NewRebootCommand(bot.API()),
		handlers.NewShutdownCommand(bot.API()),
		handlers.NewDeployCommand(bot.API(), config, svc),
		handlers.NewRollbackCommand(bot.API(), svc),
		handlers.NewUpdateCommand(bot.API(), svc),
		handlers.NewScanCommand(bot.API(), svc),
		handlers.NewSecurityCommand(bot.API(), svc),
		handlers.NewDoctorCommand(bot.API(), svc),
		handlers.NewStoreCommand(bot.API(), svc),
		handlers.NewGCCommand(bot.API(), svc),
		handlers.NewAppsCommand(bot.API(), svc),
		handlers.NewOpenCommand(bot.API(), svc),
		handlers.NewVolumeCommand(bot.API(), svc),
		handlers.NewMuteCommand(bot.API(), svc),
		handlers.NewUnmuteCommand(bot.API(), svc),
		handlers.NewBrightnessCommand(bot.API(), svc),
		handlers.NewScreenshotCommand(bot.API(), svc),
		handlers.NewClipboardCommand(bot.API(), svc),
		handlers.NewDesktopPowerCommand(bot.API(), svc),
		handlers.NewFirefoxCommand(bot.API(), svc),
		handlers.NewWindowsCommand(bot.API(), svc),
		handlers.NewWorkspaceCommand(bot.API(), svc),
		handlers.NewGitCommand(bot.API(), svc),
		handlers.NewGithubCommand(bot.API(), svc),
		handlers.NewGitlabCommand(bot.API(), svc),
		handlers.NewNixCommand(bot.API(), svc),
		handlers.NewRunCommand(bot.API(), svc),
		handlers.NewPkgCommand(bot.API(), svc),
		handlers.NewSpeedtestCommand(bot.API(), svc),
		handlers.NewTopCommand(bot.API(), svc),
		handlers.NewLogCommand(bot.API(), svc),
		handlers.NewMetricsCommand(bot.API(), svc),
		handlers.NewUsersCommand(bot.API(), svc),
		handlers.NewAddUserCommand(bot.API()),
		handlers.NewRmUserCommand(bot.API()),
		handlers.NewMenuCommand(bot.API()),
		handlers.NewStartCommand(bot.API()),
		handlers.NewNotifyCommand(bot.API(), svc),
		handlers.NewMonitorOnCommand(bot.API(), svc),
		handlers.NewAuthStatusCommand(bot.Auth(), bot.API()),
		handlers.NewGrantCommand(bot.Auth(), bot.API()),
		handlers.NewRevokeCommand(bot.Auth(), bot.API()),
		handlers.NewUsersListCommand(bot.Auth(), bot.API()),
		handlers.NewMenuInlineCommand(bot.API(), svc),
		handlers.NewUptimeCommand(bot.API(), svc),
		handlers.NewMemoryCommand(bot.API(), svc),
		handlers.NewCPUCommand(bot.API(), svc),
		handlers.NewUpdatesCommand(bot.API(), svc),
		handlers.NewDiffCommand(bot.API(), svc),
		handlers.NewGitopsReconcileCommand(bot.API(), svc),
		handlers.NewVerifyCommand(bot.API(), svc),
		handlers.NewGitopsBackupCommand(bot.API(), svc),
		handlers.NewRestoreCommand(bot.API(), svc),
		handlers.NewTailscaleCommand(bot.API(), svc),
		handlers.NewFirewallCommand(bot.API(), svc),
		handlers.NewStateCommand(bot.API(), svc),
		handlers.NewEventsCommand(bot.API(), svc),
		handlers.NewPluginsCommand(bot.API(), svc),
		handlers.NewInventoryCommand(bot.API(), svc),
		// Extra commands
		handlers.NewAICommand(bot.API(), svc),
		handlers.NewOpenCodeCommand(bot.API(), svc),
		handlers.NewNetworkCommand(bot.API(), svc),
		handlers.NewJournalCommand(bot.API(), svc),
		handlers.NewRepoCommand(bot.API(), svc),
		handlers.NewSearchCommand(bot.API(), svc),
		handlers.NewGraphCommand(bot.API(), svc),
		handlers.NewSuggestCommand(bot.API(), svc),
	)

	// Start metrics server.
	metricsAddr := ":9115"
	if v := os.Getenv("IVALI_METRICS_ADDR"); v != "" {
		metricsAddr = v
	}
	metricsSrv := metrics.NewServer(metricsAddr)
	go func() {
		fmt.Printf("Metrics server listening on %s\n", metricsAddr)
		if err := metricsSrv.Start(); err != nil && err.Error() != "http: Server closed" {
			fmt.Fprintf(os.Stderr, "Metrics server error: %v\n", err)
		}
	}()

	// Register callback handlers.
	menuInline := handlers.NewMenuInlineCommand(bot.API(), svc)
	bot.RegisterCallback("menu:", menuInline)
	bot.RegisterCallback("confirm:", &confirmHandler{bot: bot})
	bot.RegisterCallback("cancel", &confirmHandler{bot: bot})

	// Wire rate limiter and audit logger.
	rl := handlers.NewDefaultRateLimiter()
	audit := handlers.NewAuditLogger("ivali-bot")

	bot.SetBeforeExec(func(userID int, chatID int64, cmdName string) bool {
		return rl.Allow(int64(userID))
	})
	bot.SetAfterExec(func(userID int, chatID int64, cmdName string, args string, success bool, durationMs int64) {
		audit.Log(int64(userID), chatID, cmdName, args, success, durationMs)
	})

	ctx := context.Background()
	if err := runner.Run(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "Bot error: %v\n", err)
		os.Exit(1)
	}
}

type confirmHandler struct {
	bot *telegram.Bot
}

func (h *confirmHandler) HandleCallback(ctx context.Context, queryID string, chatID int64, userID int, data string, messageID int) error {
	api := h.bot.API()

	if data == "cancel" {
		if messageID > 0 {
			_ = api.EditMessageMarkdown(chatID, messageID, "❌ Cancelled")
		}
		return api.AnswerCallback(queryID, "Cancelled")
	}

	if !strings.HasPrefix(data, "confirm:") {
		return api.AnswerCallback(queryID, "Unknown action")
	}

	action := strings.TrimPrefix(data, "confirm:")
	cmd, ok := h.bot.CommandByName(action)
	if !ok {
		return api.AnswerCallback(queryID, "Unknown action: "+action)
	}

	if !h.bot.Auth().GetUserRole(userID).HasPermission(cmd.RequiredPermission()) {
		return api.AnswerCallback(queryID, "Permission denied")
	}

	msg := &telegram.Message{
		ChatID:          chatID,
		UserID:          userID,
		IsCallback:      true,
		CallbackPayload: data,
		CallbackID:      queryID,
		MessageID:       messageID,
	}

	if err := cmd.Execute(ctx, msg); err != nil {
		_ = api.AnswerCallback(queryID, "Error")
		return err
	}
	return api.AnswerCallback(queryID, "Done")
}
