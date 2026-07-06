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
