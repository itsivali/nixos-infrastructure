package bitwarden

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func SessionFromEnv() string {
	return os.Getenv("BW_SESSION")
}

func ReadSessionFromFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(data)), nil
}

func WriteSessionFile(path, session string) error {
	return os.WriteFile(path, []byte(session), 0600)
}

func FindBwPath() string {
	if p := os.Getenv("BW_PATH"); p != "" {
		return p
	}
	p, err := exec.LookPath("bw")
	if err == nil {
		return p
	}
	return "bw"
}

func SessionTTL(path string) (int, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	var ttl int
	if _, err := fmt.Sscanf(strings.TrimSpace(string(data)), "%d", &ttl); err != nil {
		return 0, err
	}
	return ttl, nil
}

func WriteSessionTTL(path string, ttl int) error {
	return os.WriteFile(path, []byte(fmt.Sprintf("%d\n", ttl)), 0600)
}

// ReadMasterPasswordFromFile returns the master password from the SOPS secret
// file pointed to by the BW_MASTER_PASSWORD_FILE environment variable.
// Returns empty string if the env var is unset or the file is missing/empty.
func ReadMasterPasswordFromFile() (string, error) {
	path := os.Getenv("BW_MASTER_PASSWORD_FILE")
	if path == "" {
		return "", nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("reading master password file %q: %w", path, err)
	}
	password := strings.TrimSpace(string(data))
	if password == "" {
		return "", nil
	}
	return password, nil
}

// ReadSopsEmailFromFile returns the Bitwarden email from the SOPS secret
// file pointed to by the BW_SOPS_EMAIL_FILE environment variable.
// Returns empty string if the env var is unset or the file is missing/empty.
func ReadSopsEmailFromFile() (string, error) {
	path := os.Getenv("BW_SOPS_EMAIL_FILE")
	if path == "" {
		return "", nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("reading SOPS email file %q: %w", path, err)
	}
	email := strings.TrimSpace(string(data))
	if email == "" {
		return "", nil
	}
	return email, nil
}
