package main

import (
	"context"
	"flag"
	"fmt"
	"os"

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
	)

	// Run the bot
	ctx := context.Background()
	if err := runner.Run(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "Bot error: %v\n", err)
		os.Exit(1)
	}
}
