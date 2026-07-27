package handlers

import (
	"context"
	"strings"
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
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
				return
			}
			if tt.name == "exit code" {
				return
			}
			if !strings.Contains(got, tt.want) {
				t.Errorf("runCmd(%q) = %q, want contains %q", tt.cmd, got, tt.want)
			}
		})
	}
}

func TestCommandNames(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")

	commands := []telegram.Command{
		NewAppsCommand(api, svc),
		NewOpenCommand(api, svc),
		NewVolumeCommand(api, svc),
		NewMuteCommand(api, svc),
		NewUnmuteCommand(api, svc),
		NewBrightnessCommand(api, svc),
		NewScreenshotCommand(api, svc),
		NewClipboardCommand(api, svc),
		NewDesktopPowerCommand(api, svc),
		NewFirefoxCommand(api, svc),
		NewGitCommand(api, svc),
		NewGithubCommand(api, svc),
		NewGitlabCommand(api, svc),
		NewNixCommand(api, svc),
		NewRunCommand(api, svc),
		NewPkgCommand(api, svc),
		NewSpeedtestCommand(api, svc),
		NewTopCommand(api, svc),
		NewLogCommand(api, svc),
		NewMetricsCommand(api, svc),
		NewWindowsCommand(api, svc),
		NewWorkspaceCommand(api, svc),
		NewUsersCommand(api, svc),
		NewAddUserCommand(api),
		NewRmUserCommand(api),
		NewMenuCommand(api),
		NewStartCommand(api),
		NewNotifyCommand(api, svc),
		NewMonitorOnCommand(api, svc),
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
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")

	commands := []struct {
		name string
		cmd  telegram.Command
	}{
		{"apps", NewAppsCommand(api, svc)},
		{"open", NewOpenCommand(api, svc)},
		{"volume", NewVolumeCommand(api, svc)},
		{"mute", NewMuteCommand(api, svc)},
		{"unmute", NewUnmuteCommand(api, svc)},
		{"brightness", NewBrightnessCommand(api, svc)},
		{"menu", NewMenuCommand(api)},
		{"start", NewStartCommand(api)},
	}

	ctx := context.Background()
	for _, tc := range commands {
		t.Run(tc.name, func(t *testing.T) {
			msg := &telegram.Message{
				ChatID:   123,
				UserID:   123,
				Username: "test",
				Text:     "/" + tc.name,
				Command:  tc.name,
				Args:     "",
			}
			_ = tc.cmd.Execute(ctx, msg)
		})
	}
}

func TestCommandPermissions(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")

	tests := []struct {
		name       string
		cmd        telegram.Command
		permission telegram.Role
	}{
		{"guest commands", NewStartCommand(api), telegram.RoleGuest},
		{"guest commands menu", NewMenuCommand(api), telegram.RoleGuest},
		{"user commands apps", NewAppsCommand(api, svc), telegram.RoleUser},
		{"user commands open", NewOpenCommand(api, svc), telegram.RoleUser},
		{"user commands volume", NewVolumeCommand(api, svc), telegram.RoleUser},
		{"admin commands nix", NewNixCommand(api, svc), telegram.RoleAdmin},
		{"admin commands run", NewRunCommand(api, svc), telegram.RoleAdmin},
		{"admin commands deploy", NewDeployCommand(api, &telegram.Config{RepoDir: "/tmp"}, svc), telegram.RoleAdmin},
		{"owner commands users", NewUsersCommand(api, svc), telegram.RoleOwner},
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
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")
	cmd := NewOpenCommand(api, svc)

	msg := &telegram.Message{ChatID: 123, Args: ""}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestDesktopPowerCommandInvalidArgs(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")
	cmd := NewDesktopPowerCommand(api, svc)

	msg := &telegram.Message{ChatID: 123, Args: "invalid"}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestNixCommandEmptyArgs(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")
	cmd := NewNixCommand(api, svc)

	msg := &telegram.Message{ChatID: 123, Args: ""}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestRunCommandEmptyArgs(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")
	cmd := NewRunCommand(api, svc)

	msg := &telegram.Message{ChatID: 123, Args: ""}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestNotifyCommandEmptyArgs(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")
	cmd := NewNotifyCommand(api, svc)

	msg := &telegram.Message{ChatID: 123, Args: ""}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestClipboardCommandSet(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")
	cmd := NewClipboardCommand(api, svc)

	msg := &telegram.Message{ChatID: 123, Args: "set hello world"}
	err := cmd.Execute(context.Background(), msg)
	_ = err
}

func TestAllCommandsImplementInterface(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")

	allCommands := []telegram.Command{
		NewAppsCommand(api, svc),
		NewOpenCommand(api, svc),
		NewVolumeCommand(api, svc),
		NewMuteCommand(api, svc),
		NewUnmuteCommand(api, svc),
		NewBrightnessCommand(api, svc),
		NewScreenshotCommand(api, svc),
		NewClipboardCommand(api, svc),
		NewDesktopPowerCommand(api, svc),
		NewFirefoxCommand(api, svc),
		NewGitCommand(api, svc),
		NewGithubCommand(api, svc),
		NewGitlabCommand(api, svc),
		NewNixCommand(api, svc),
		NewRunCommand(api, svc),
		NewPkgCommand(api, svc),
		NewSpeedtestCommand(api, svc),
		NewTopCommand(api, svc),
		NewLogCommand(api, svc),
		NewMetricsCommand(api, svc),
		NewWindowsCommand(api, svc),
		NewWorkspaceCommand(api, svc),
		NewUsersCommand(api, svc),
		NewAddUserCommand(api),
		NewRmUserCommand(api),
		NewMenuCommand(api),
		NewStartCommand(api),
		NewNotifyCommand(api, svc),
		NewMonitorOnCommand(api, svc),
		NewStatusCommand(api, svc),
		NewHealthCommand(api, svc),
		NewDiskCommand(api, svc),
		NewProcessesCommand(api, svc),
		NewGenerationsCommand(api, svc),
		NewRebootCommand(api),
		NewShutdownCommand(api),
		NewDeployCommand(api, &telegram.Config{RepoDir: "/tmp"}, svc),
		NewRollbackCommand(api, svc),
		NewUpdateCommand(api, svc),
		NewScanCommand(api, svc),
		NewSecurityCommand(api, svc),
		NewDoctorCommand(api, svc),
		NewStoreCommand(api, svc),
		NewGCCommand(api, svc),
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
