package bitwarden

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"
)

// ageKeyFile returns the path to the SOPS age key file, or empty if unset.
func ageKeyFile() string {
	return os.Getenv("SOPS_AGE_KEY_FILE")
}

// ReadCache reads and deserializes vault items from the cache file.
// If the file is age-encrypted (and SOPS_AGE_KEY_FILE is set), it decrypts first.
// Falls back to plaintext if decryption fails (backward compatibility).
func ReadCache(path string) ([]VaultItem, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read cache: %w", err)
	}

	var items []VaultItem

	// Try age decryption if key file is available
	if keyFile := ageKeyFile(); keyFile != "" && len(data) > 0 {
		if decrypted, err := DecryptWithAge(data, keyFile); err == nil {
			data = decrypted
		}
		// If decryption fails, assume plaintext (backward compat)
	}

	if err := json.Unmarshal(data, &items); err != nil {
		return nil, fmt.Errorf("parse cache: %w", err)
	}
	return items, nil
}

func ReadCacheTime(path string) (time.Time, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return time.Time{}, err
	}
	t, err := time.Parse(time.RFC3339, strings.TrimSpace(string(data)))
	if err != nil {
		return time.Time{}, err
	}
	return t, nil
}

func IsCacheStale(cacheTimePath string, ttl time.Duration) bool {
	t, err := ReadCacheTime(cacheTimePath)
	if err != nil {
		return true
	}
	return time.Since(t) > ttl
}

// WriteCache serializes vault items and writes them to the cache file.
// If SOPS_AGE_KEY_FILE is set, the cache is encrypted using age before writing.
// The cache file is always mode 0600.
func WriteCache(path string, items []VaultItem) error {
	data, err := json.Marshal(items)
	if err != nil {
		return fmt.Errorf("marshal cache: %w", err)
	}

	// Attempt age encryption if a key file is available
	if keyFile := ageKeyFile(); keyFile != "" {
		if encrypted, err := EncryptWithAgeKeyFile(data, keyFile); err == nil {
			data = encrypted
		}
		// If encryption fails, write plaintext (non-fatal)
	}

	if err := os.WriteFile(path, data, 0600); err != nil {
		return fmt.Errorf("write cache: %w", err)
	}
	return nil
}

func WriteCacheTime(path string) error {
	t := time.Now().Format(time.RFC3339)
	return os.WriteFile(path, []byte(t+"\n"), 0600)
}
