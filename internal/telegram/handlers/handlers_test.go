package handlers

import (
	"context"
	"strings"
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

func TestRunCmd(t *testing.T) {
	tests := []struct {
		name    string
		cmd     string
		timeout int
		want    string
	}{
		{"echo", "echo hello", 5, "hello"},
		{"exit code", "exit 1", 5, ""},
		{"timeout", "sleep 10", 1, "Command timed out"},
		{"empty", "", 5, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := runCmd(tt.cmd, tt.timeout)
			if tt.name == "timeout" {
				if !strings.Contains(got, "timed out") {
					t.Errorf("runCmd(%q) = %q, want timeout message", tt.cmd, got)
				}
				return
			}
			if tt.name == "empty" {
				// empty command might error or produce no output
				return
			}
			if tt.name == "exit code" {
				// exit 1 produces empty stdout
				return
			}
			if !strings.Contains(got, tt.want) {
				t.Errorf("runCmd(%q) = %q, want contains %q", tt.cmd, got, tt.want)
			}
		})
	}
}

func TestCommandNames(t *testing.T) {
	config := &telegram.Config{
		BotToken: "test-token",
		ChatID:   123,
	}

	commands := []telegram.Command{
		NewAppsCommand(config),
		NewOpenCommand(config),
		NewVolumeCommand(config),
		NewMuteCommand(config),
		NewUnmuteCommand(config),
		NewBrightnessCommand(config),
		NewScreenshotCommand(config),
		NewClipboardCommand(config),
		NewDesktopPowerCommand(config),
		NewFirefoxCommand(config),
		NewGitCommand(config),
		NewGithubCommand(config),
		NewGitlabCommand(config),
		NewNixCommand(config),
		NewRunCommand(config),
		NewPkgCommand(config),
		NewSpeedtestCommand(config),
		NewTopCommand(config),
		NewLogCommand(config),
		NewBackupCommand(config),
		NewMetricsCommand(config),
		NewCancelCommand(config),
		NewWindowsCommand(config),
		NewWorkspaceCommand(config),
		NewUsersCommand(config),
		NewAddUserCommand(config),
		NewRmUserCommand(config),
		NewMenuCommand(config),
		NewStartCommand(config),
		NewNotifyCommand(config),
		NewMonitorOnCommand(config),
	}

	seen := make(map[string]bool)
	for _, cmd := range commands {
		name := cmd.Name()
		if name == "" {
			t.Error("command has empty name")
		}
		if seen[name] {
			t.Errorf("duplicate command name: %s", name)
		}
		seen[name] = true

		if cmd.Description() == "" {
			t.Errorf("command %s has empty description", name)
		}
	}
}

func TestCommandsAreCallable(t *testing.T) {
	config := &telegram.Config{
		BotToken: "test-token",
		ChatID:   123,
		StateDir: t.TempDir(),
	}

	commands := []struct {
		name string
		cmd  telegram.Command
	}{
		{"apps", NewAppsCommand(config)},
		{"open", NewOpenCommand(config)},
		{"volume", NewVolumeCommand(config)},
		{"mute", NewMuteCommand(config)},
		{"unmute", NewUnmuteCommand(config)},
		{"brightness", NewBrightnessCommand(config)},
		{"cancel", NewCancelCommand(config)},
		{"menu", NewMenuCommand(config)},
		{"start", NewStartCommand(config)},
	}

	ctx := context.Background()
	for _, tc := range commands {
		t.Run(tc.name, func(t *testing.T) {
			msg := &telegram.Message{
				ChatID:   config.ChatID,
				UserID:   123,
				Username: "test",
				Text:     "/" + tc.name,
				Command:  tc.name,
				Args:     "",
			}

			// Commands will fail because we don't have a real API
			// but they should not panic
			_ = tc.cmd.Execute(ctx, msg)
		})
	}
}

func TestCommandPermissions(t *testing.T) {
	config := &telegram.Config{BotToken: "test-token"}

	tests := []struct {
		name       string
		cmd        telegram.Command
		permission telegram.Role
	}{
		{"guest commands", NewStartCommand(config), telegram.RoleGuest},
		{"guest commands menu", NewMenuCommand(config), telegram.RoleGuest},
		{"user commands apps", NewAppsCommand(config), telegram.RoleUser},
		{"user commands open", NewOpenCommand(config), telegram.RoleUser},
		{"user commands volume", NewVolumeCommand(config), telegram.RoleUser},
		{"admin commands nix", NewNixCommand(config), telegram.RoleAdmin},
		{"admin commands run", NewRunCommand(config), telegram.RoleAdmin},
		{"admin commands deploy", NewDeployCommand(config), telegram.RoleAdmin},
		{"owner commands users", NewUsersCommand(config), telegram.RoleOwner},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.cmd.RequiredPermission() != tt.permission {
				t.Errorf("%s: got permission %v, want %v",
					tt.name, tt.cmd.RequiredPermission(), tt.permission)
			}
		})
	}
}

func TestOpenCommandEmptyArgs(t *testing.T) {
	config := &telegram.Config{BotToken: "test-token", ChatID: 123}
	cmd := NewOpenCommand(config)

	msg := &telegram.Message{ChatID: 123, Args: ""}
	err := cmd.Execute(context.Background(), msg)
	_ = err // API call fails but should not panic
}

func TestDesktopPowerCommandInvalidArgs(t *testing.T) {
	config := &telegram.Config{BotToken: "test-token", ChatID: 123}
	cmd := NewDesktopPowerCommand(config)

	msg := &telegram.Message{ChatID: 123, Args: "invalid"}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestNixCommandEmptyArgs(t *testing.T) {
	config := &telegram.Config{BotToken: "test-token", ChatID: 123}
	cmd := NewNixCommand(config)

	msg := &telegram.Message{ChatID: 123, Args: ""}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestRunCommandEmptyArgs(t *testing.T) {
	config := &telegram.Config{BotToken: "test-token", ChatID: 123}
	cmd := NewRunCommand(config)

	msg := &telegram.Message{ChatID: 123, Args: ""}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestNotifyCommandEmptyArgs(t *testing.T) {
	config := &telegram.Config{BotToken: "test-token", ChatID: 123}
	cmd := NewNotifyCommand(config)

	msg := &telegram.Message{ChatID: 123, Args: ""}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestClipboardCommandSet(t *testing.T) {
	config := &telegram.Config{BotToken: "test-token", ChatID: 123}
	cmd := NewClipboardCommand(config)

	msg := &telegram.Message{ChatID: 123, Args: "set hello world"}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestAllCommandsImplementInterface(t *testing.T) {
	config := &telegram.Config{BotToken: "test-token"}

	allCommands := []telegram.Command{
		NewAppsCommand(config),
		NewOpenCommand(config),
		NewVolumeCommand(config),
		NewMuteCommand(config),
		NewUnmuteCommand(config),
		NewBrightnessCommand(config),
		NewScreenshotCommand(config),
		NewClipboardCommand(config),
		NewDesktopPowerCommand(config),
		NewFirefoxCommand(config),
		NewGitCommand(config),
		NewGithubCommand(config),
		NewGitlabCommand(config),
		NewNixCommand(config),
		NewRunCommand(config),
		NewPkgCommand(config),
		NewSpeedtestCommand(config),
		NewTopCommand(config),
		NewLogCommand(config),
		NewBackupCommand(config),
		NewMetricsCommand(config),
		NewCancelCommand(config),
		NewWindowsCommand(config),
		NewWorkspaceCommand(config),
		NewUsersCommand(config),
		NewAddUserCommand(config),
		NewRmUserCommand(config),
		NewMenuCommand(config),
		NewStartCommand(config),
		NewNotifyCommand(config),
		NewMonitorOnCommand(config),
		NewStatusCommand(config),
		NewHealthCommand(config),
		NewDiskCommand(config),
		NewProcessesCommand(config),
		NewGenerationsCommand(config),
		NewRebootCommand(config),
		NewShutdownCommand(config),
		NewDeployCommand(config),
		NewRollbackCommand(config),
		NewUpdateCommand(config),
		NewScanCommand(config),
		NewSecurityCommand(config),
		NewDoctorCommand(config),
		NewStoreCommand(config),
		NewGCCommand(config),
	}

	for _, cmd := range allCommands {
		if cmd.Name() == "" {
			t.Errorf("command has empty Name()")
		}
		if cmd.Description() == "" {
			t.Errorf("command %s has empty Description()", cmd.Name())
		}
		perm := cmd.RequiredPermission()
		if perm < telegram.RoleGuest || perm > telegram.RoleOwner {
			t.Errorf("command %s has invalid permission: %v", cmd.Name(), perm)
		}
	}
}
