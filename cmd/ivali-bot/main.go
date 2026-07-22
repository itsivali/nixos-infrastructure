package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/willisivali/nixos-infrastructure/internal/telegram"
	"github.com/willisivali/nixos-infrastructure/internal/telegram/handlers"
)

func main() {
	debug := flag.Bool("debug", false, "Enable debug logging")
	flag.Parse()

	// Load configuration
	config, err := telegram.LoadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load config: %v\n", err)
		os.Exit(1)
	}

	config.Debug = *debug

	// Create logger
	logger := telegram.NewSimpleLogger(config.Debug)

	// Create runner
	runner := telegram.NewRunner(config, logger)

	// Register commands
	bot := runner.Bot()
	bot.RegisterCommands(
		handlers.NewHelpCommand(bot),
		handlers.NewStatusCommand(config),
		handlers.NewHealthCommand(config),
		handlers.NewDiskCommand(config),
		handlers.NewProcessesCommand(config),
		handlers.NewGenerationsCommand(config),
		handlers.NewRebootCommand(config),
		handlers.NewShutdownCommand(config),
		handlers.NewDeployCommand(config),
		handlers.NewRollbackCommand(config),
		handlers.NewUpdateCommand(config),
		handlers.NewScanCommand(config),
		handlers.NewSecurityCommand(config),
		handlers.NewDoctorCommand(config),
		handlers.NewStoreCommand(config),
		handlers.NewGCCommand(config),
		handlers.NewAppsCommand(config),
		handlers.NewOpenCommand(config),
		handlers.NewVolumeCommand(config),
		handlers.NewMuteCommand(config),
		handlers.NewUnmuteCommand(config),
		handlers.NewBrightnessCommand(config),
		handlers.NewScreenshotCommand(config),
		handlers.NewClipboardCommand(config),
		handlers.NewDesktopPowerCommand(config),
		handlers.NewFirefoxCommand(config),
		handlers.NewGitCommand(config),
		handlers.NewGithubCommand(config),
		handlers.NewGitlabCommand(config),
		handlers.NewNixCommand(config),
		handlers.NewRunCommand(config),
		handlers.NewPkgCommand(config),
		handlers.NewSpeedtestCommand(config),
		handlers.NewTopCommand(config),
		handlers.NewLogCommand(config),
		handlers.NewBackupCommand(config),
		handlers.NewMetricsCommand(config),
		handlers.NewCancelCommand(config),
		handlers.NewWindowsCommand(config),
		handlers.NewWorkspaceCommand(config),
		handlers.NewUsersCommand(config),
		handlers.NewAddUserCommand(config),
		handlers.NewRmUserCommand(config),
		handlers.NewMenuCommand(config),
		handlers.NewStartCommand(config),
		handlers.NewNotifyCommand(config),
		handlers.NewMonitorOnCommand(config),
		handlers.NewAuthStatusCommand(bot.Auth(), bot.API()),
		handlers.NewGrantCommand(bot.Auth(), bot.API()),
		handlers.NewRevokeCommand(bot.Auth(), bot.API()),
		handlers.NewUsersListCommand(bot.Auth(), bot.API()),
		// New commands
		handlers.NewMenuInlineCommand(config),
		handlers.NewUptimeCommand(config),
		handlers.NewMemoryCommand(config),
		handlers.NewCPUCommand(config),
		handlers.NewUpdatesCommand(config),
		handlers.NewDiffCommand(config),
		handlers.NewGitopsReconcileCommand(config),
		handlers.NewVerifyCommand(config),
		handlers.NewGitopsBackupCommand(config),
		handlers.NewRestoreCommand(config),
		handlers.NewTailscaleCommand(config),
		handlers.NewFirewallCommand(config),
		// Jules commands
		handlers.NewJulesStatusCommand(config),
		handlers.NewJulesTasksCommand(config),
		handlers.NewJulesNewCommand(config),
		handlers.NewJulesCancelCommand(config),
		handlers.NewJulesHistoryCommand(config),
	)

	// Register inline-keyboard callback handlers.
	bot.RegisterCallback("confirm:", &confirmHandler{bot: bot})
	bot.RegisterCallback("cancel", &confirmHandler{bot: bot})

	// Run the bot
	ctx := context.Background()
	if err := runner.Run(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "Bot error: %v\n", err)
		os.Exit(1)
	}
}

// confirmHandler routes inline-keyboard "confirm:<action>" / "cancel" payloads
// to the corresponding registered command. The originating command decides
// whether the payload is the actual confirmation (msg.IsCallback &&
// CallbackData == "confirm:<action>") or just a request to show the prompt.
type confirmHandler struct {
	bot *telegram.Bot
}

func (h *confirmHandler) HandleCallback(ctx context.Context, queryID string, chatID int64, userID int, data string) error {
	api := h.bot.API()

	if data == "cancel" {
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

	// Re-check permissions for the user who pressed the button.
	if !h.bot.Auth().GetUserRole(userID).HasPermission(cmd.RequiredPermission()) {
		return api.AnswerCallback(queryID, "Permission denied")
	}

	msg := &telegram.Message{
		ChatID:          chatID,
		UserID:          userID,
		IsCallback:      true,
		CallbackPayload: data,
		CallbackID:      queryID,
	}

	if err := cmd.Execute(ctx, msg); err != nil {
		_ = api.AnswerCallback(queryID, "Error")
		return err
	}
	return api.AnswerCallback(queryID, "Done")
}
