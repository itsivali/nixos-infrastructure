package telegram

import (
	"fmt"
	"log"
	"os"
	"strings"
)

// SimpleLogger is a basic logger implementation.
type SimpleLogger struct {
	debug bool
}

// NewSimpleLogger creates a new SimpleLogger.
func NewSimpleLogger(debug bool) *SimpleLogger {
	return &SimpleLogger{debug: debug}
}

func (l *SimpleLogger) Info(msg string, args ...any) {
	l.log("INFO", msg, args...)
}

func (l *SimpleLogger) Error(msg string, args ...any) {
	l.log("ERROR", msg, args...)
}

func (l *SimpleLogger) Debug(msg string, args ...any) {
	if l.debug {
		l.log("DEBUG", msg, args...)
	}
}

func (l *SimpleLogger) log(level, msg string, args ...any) {
	parts := []string{fmt.Sprintf("[%s] %s", level, msg)}
	for i := 0; i < len(args)-1; i += 2 {
		parts = append(parts, fmt.Sprintf("%v=%v", args[i], args[i+1]))
	}
	log.Println(strings.Join(parts, " "))
}

// Config holds the bot configuration.
type Config struct {
	BotToken   string
	ChatID     int64
	StateDir   string
	RepoDir    string
	Hostname   string
	Debug      bool
	MaxAgeSecs int
}

// LoadConfig loads configuration from environment variables and SOPS secrets.
func LoadConfig() (*Config, error) {
	cfg := &Config{
		BotToken:   os.Getenv("BOT_TOKEN"),
		ChatID:     0,
		StateDir:   "/var/lib/ivali-bot",
		RepoDir:    "/home/ivali/nixos-infrastructure",
		Hostname:   mustHostname(),
		Debug:      os.Getenv("DEBUG") == "true",
		MaxAgeSecs: 300,
	}

	// Read ChatID from environment
	if chatIDStr := os.Getenv("CHAT_ID"); chatIDStr != "" {
		var chatID int64
		if _, err := fmt.Sscanf(chatIDStr, "%d", &chatID); err != nil {
			return nil, fmt.Errorf("invalid CHAT_ID: %w", err)
		}
		cfg.ChatID = chatID
	}

	// Try reading from SOPS secrets if not in environment
	if cfg.BotToken == "" {
		data, err := os.ReadFile("/run/secrets/telegram_bot_token")
		if err == nil {
			cfg.BotToken = strings.TrimSpace(string(data))
		}
	}

	if cfg.ChatID == 0 {
		data, err := os.ReadFile("/run/secrets/telegram_chat_id")
		if err == nil {
			var chatID int64
			if _, err := fmt.Sscanf(strings.TrimSpace(string(data)), "%d", &chatID); err == nil {
				cfg.ChatID = chatID
			}
		}
	}

	if cfg.BotToken == "" {
		return nil, fmt.Errorf("BOT_TOKEN not set and /run/secrets/telegram_bot_token not found")
	}

	if cfg.ChatID == 0 {
		return nil, fmt.Errorf("CHAT_ID not set and /run/secrets/telegram_chat_id not found")
	}

	return cfg, nil
}

func mustHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return hostname
}
