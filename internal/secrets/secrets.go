package secrets

import (
	"os"
	"path/filepath"
	"strings"
)

const (
	// DefaultSecretsDir is the default SOPS secrets mount point.
	DefaultSecretsDir = "/run/secrets"

	// Secret names for Telegram bot configuration.
	SecretTelegramBotToken = "telegram_bot_token"
	SecretTelegramChatID   = "telegram_chat_id"

	// Secret names for GitLab runner.
	SecretGitLabRunnerToken = "gitlab_runner_token"

	// Secret names for SOPS.
	SecretSOPSKey = "sops_key"
)

// ReadSecret reads a secret from the SOPS secrets directory.
// It first checks the environment variable <NAME>_FILE for a file path,
// then falls back to DefaultSecretsDir/<name>.
func ReadSecret(name string) (string, error) {
	// Check for file-based secret (standard SOPS pattern)
	fileEnv := os.Getenv(strings.ToUpper(name) + "_FILE")
	if fileEnv != "" {
		data, err := os.ReadFile(fileEnv)
		if err != nil {
			return "", err
		}
		return strings.TrimSpace(string(data)), nil
	}

	// Check for direct environment variable
	envVal := os.Getenv(strings.ToUpper(name))
	if envVal != "" {
		return envVal, nil
	}

	// Fall back to secrets directory
	secretsDir := os.Getenv("SECRETS_DIR")
	if secretsDir == "" {
		secretsDir = DefaultSecretsDir
	}

	data, err := os.ReadFile(filepath.Join(secretsDir, name))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(data)), nil
}

// ReadTelegramBotToken reads the Telegram bot token from secrets.
func ReadTelegramBotToken() (string, error) {
	return ReadSecret(SecretTelegramBotToken)
}

// ReadTelegramChatID reads the Telegram chat ID from secrets.
func ReadTelegramChatID() (string, error) {
	return ReadSecret(SecretTelegramChatID)
}
