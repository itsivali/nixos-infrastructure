package bitwarden

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"
)

func ReadCache(path string) ([]VaultItem, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read cache: %w", err)
	}
	var items []VaultItem
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

func WriteCache(path string, items []VaultItem) error {
	data, err := json.Marshal(items)
	if err != nil {
		return fmt.Errorf("marshal cache: %w", err)
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
