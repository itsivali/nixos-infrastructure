package telegram

import (
	"context"
	"testing"
	"time"
)

type mockLogger struct {
	messages []string
}

func (l *mockLogger) Info(msg string, args ...any)  { l.messages = append(l.messages, msg) }
func (l *mockLogger) Error(msg string, args ...any) { l.messages = append(l.messages, msg) }
func (l *mockLogger) Debug(msg string, args ...any) { l.messages = append(l.messages, msg) }

func TestIntegrationDispatchAllCommands(t *testing.T) {
	api := NewAPI("test-token")
	auth := NewAuth(t.TempDir())
	logger := &mockLogger{}
	bot := New(api, auth, logger)

	// Register a test command
	bot.RegisterCommand(NewCommandFunc("test", "Test command", RoleGuest, func(ctx context.Context, msg *Message) error {
		return nil
	}))

	tests := []struct {
		name    string
		text    string
		wantCmd string
		wantArgs string
	}{
		{"simple command", "/test", "test", ""},
		{"command with args", "/test foo bar", "test", "foo bar"},
		{"unknown command", "/unknown", "", ""},
		{"no prefix", "test", "", ""},
		{"empty text", "", "", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			msg := &Message{
				ChatID: 123,
				UserID: 456,
				Text:   tt.text,
			}

			// Dispatch will fail for API calls but should not panic
			_ = bot.Dispatch(context.Background(), msg)

			if tt.wantCmd != "" && msg.Command != tt.wantCmd {
				t.Errorf("got command %q, want %q", msg.Command, tt.wantCmd)
			}
			if tt.wantArgs != "" && msg.Args != tt.wantArgs {
				t.Errorf("got args %q, want %q", msg.Args, tt.wantArgs)
			}
		})
	}
}

func TestIntegrationRegisterMultipleCommands(t *testing.T) {
	api := NewAPI("test-token")
	auth := NewAuth(t.TempDir())
	logger := &mockLogger{}
	bot := New(api, auth, logger)

	commands := []Command{
		NewCommandFunc("cmd1", "First", RoleGuest, func(ctx context.Context, msg *Message) error { return nil }),
		NewCommandFunc("cmd2", "Second", RoleUser, func(ctx context.Context, msg *Message) error { return nil }),
		NewCommandFunc("cmd3", "Third", RoleAdmin, func(ctx context.Context, msg *Message) error { return nil }),
	}

	bot.RegisterCommands(commands...)

	if len(bot.GetCommands()) != 3 {
		t.Errorf("got %d commands, want 3", len(bot.GetCommands()))
	}
}

func TestIntegrationCallbackRegistration(t *testing.T) {
	api := NewAPI("test-token")
	auth := NewAuth(t.TempDir())
	logger := &mockLogger{}
	bot := New(api, auth, logger)

	bot.RegisterCallback("test_", &mockCallbackHandler{fn: func(ctx context.Context, queryID string, chatID int64, userID int, data string) error {
		return nil
	}})

	if len(bot.callbacks) != 1 {
		t.Errorf("got %d callbacks, want 1", len(bot.callbacks))
	}
}

type mockCallbackHandler struct {
	fn func(ctx context.Context, queryID string, chatID int64, userID int, data string) error
}

func (h *mockCallbackHandler) HandleCallback(ctx context.Context, queryID string, chatID int64, userID int, data string) error {
	return h.fn(ctx, queryID, chatID, userID, data)
}

func TestRunnerIsRecent(t *testing.T) {
	config := &Config{MaxAgeSecs: 300}
	runner := &Runner{config: config}

	// Use current timestamp (should be recent)
	now := time.Now().Unix()
	if !runner.isRecent(now) {
		t.Error("expected current timestamp to be recent")
	}

	// Use old timestamp (should not be recent)
	old := int64(1000000000) // 2001
	if runner.isRecent(old) {
		t.Error("expected old timestamp to not be recent")
	}
}
