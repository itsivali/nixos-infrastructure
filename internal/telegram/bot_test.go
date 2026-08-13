package telegram

import (
	"context"
	"testing"
)

func TestRoleHasPermission(t *testing.T) {
	tests := []struct {
		role     Role
		required Role
		want     bool
	}{
		{RoleOwner, RoleGuest, true},
		{RoleOwner, RoleUser, true},
		{RoleOwner, RoleAdmin, true},
		{RoleOwner, RoleOwner, true},
		{RoleAdmin, RoleGuest, true},
		{RoleAdmin, RoleUser, true},
		{RoleAdmin, RoleAdmin, true},
		{RoleAdmin, RoleOwner, false},
		{RoleUser, RoleGuest, true},
		{RoleUser, RoleUser, true},
		{RoleUser, RoleAdmin, false},
		{RoleGuest, RoleGuest, true},
		{RoleGuest, RoleUser, false},
	}

	for _, tt := range tests {
		t.Run(tt.role.String()+"_"+tt.required.String(), func(t *testing.T) {
			if got := tt.role.HasPermission(tt.required); got != tt.want {
				t.Errorf("Role(%s).HasPermission(%s) = %v, want %v", tt.role, tt.required, got, tt.want)
			}
		})
	}
}

func TestParseRole(t *testing.T) {
	tests := []struct {
		input string
		want  Role
	}{
		{"owner", RoleOwner},
		{"admin", RoleAdmin},
		{"user", RoleUser},
		{"guest", RoleGuest},
		{"OWNER", RoleOwner},
		{"unknown", RoleGuest},
		{"", RoleGuest},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			if got := ParseRole(tt.input); got != tt.want {
				t.Errorf("ParseRole(%q) = %v, want %v", tt.input, got, tt.want)
			}
		})
	}
}

func TestRoleString(t *testing.T) {
	tests := []struct {
		role Role
		want string
	}{
		{RoleOwner, "owner"},
		{RoleAdmin, "admin"},
		{RoleUser, "user"},
		{RoleGuest, "guest"},
	}

	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			if got := tt.role.String(); got != tt.want {
				t.Errorf("Role.String() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestBotRegisterCommand(t *testing.T) {
	bot := New(nil, nil, NewSimpleLogger(false))

	cmd := NewCommandFunc("test", "A test command", RoleUser, nil)
	bot.RegisterCommand(cmd)

	cmds := bot.GetCommands()
	if len(cmds) != 1 {
		t.Fatalf("expected 1 command, got %d", len(cmds))
	}
	if cmds[0].Name() != "test" {
		t.Errorf("expected command name 'test', got %q", cmds[0].Name())
	}
}

func TestBotRegisterMultipleCommands(t *testing.T) {
	bot := New(nil, nil, NewSimpleLogger(false))

	cmd1 := NewCommandFunc("cmd1", "Command 1", RoleUser, nil)
	cmd2 := NewCommandFunc("cmd2", "Command 2", RoleAdmin, nil)
	cmd3 := NewCommandFunc("cmd3", "Command 3", RoleGuest, nil)

	bot.RegisterCommands(cmd1, cmd2, cmd3)

	cmds := bot.GetCommands()
	if len(cmds) != 3 {
		t.Fatalf("expected 3 commands, got %d", len(cmds))
	}
}

func TestCommandFunc(t *testing.T) {
	called := false
	cmd := NewCommandFunc("test", "Test command", RoleUser, func(ctx context.Context, msg *Message) error {
		called = true
		return nil
	})

	if cmd.Name() != "test" {
		t.Errorf("expected name 'test', got %q", cmd.Name())
	}
	if cmd.Description() != "Test command" {
		t.Errorf("expected description 'Test command', got %q", cmd.Description())
	}
	if cmd.RequiredPermission() != RoleUser {
		t.Errorf("expected permission RoleUser, got %v", cmd.RequiredPermission())
	}

	msg := &Message{}
	_ = cmd.Execute(context.Background(), msg)

	if !called {
		t.Error("expected handler to be called")
	}
}

func TestNewSimpleLogger(t *testing.T) {
	logger := NewSimpleLogger(false)
	if logger == nil {
		t.Fatal("expected non-nil logger")
	}

	// Test that it doesn't panic
	logger.Info("test message", "key", "value")
	logger.Error("test error", "key", "value")
}

func TestNewSimpleLoggerDebug(t *testing.T) {
	logger := NewSimpleLogger(true)
	if logger == nil {
		t.Fatal("expected non-nil logger")
	}

	// Debug should work when debug is enabled
	logger.Debug("debug message", "key", "value")
}

func TestNormalizeCommandText(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"/status", "/status"},
		{"🖥 /status", "/status"},
		{"💓 /health extra args", "/health extra args"},
		{"  /status  ", "/status  "},
		{"", ""},
		{"   ", ""},
		{"just text", "just text"},
		{"🖥/status", "/status"},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			if got := normalizeCommandText(tt.input); got != tt.want {
				t.Errorf("normalizeCommandText(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestDispatchReplyKeyboardEmoji(t *testing.T) {
	bot := New(nil, NewAuth(t.TempDir()), NewSimpleLogger(false))
	executed := false
	bot.RegisterCommand(NewCommandFunc("status", "status", RoleGuest, func(ctx context.Context, msg *Message) error {
		executed = true
		if msg.Command != "status" {
			t.Errorf("Command = %q, want %q", msg.Command, "status")
		}
		return nil
	}))

	// A reply-keyboard button label with a leading emoji must dispatch.
	err := bot.Dispatch(context.Background(), &Message{
		ChatID: 1,
		UserID: 2,
		Text:   "🖥 /status",
	})
	if err != nil {
		t.Fatalf("Dispatch with emoji prefix failed: %v", err)
	}
	if !executed {
		t.Error("expected command to execute for emoji-prefixed keyboard label")
	}
}
