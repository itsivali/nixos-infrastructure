package bitwarden

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

type Client struct {
	BwPath  string
	Session string
}

func NewClient(bwPath, session string) *Client {
	return &Client{BwPath: bwPath, Session: session}
}

func (c *Client) run(args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, c.BwPath, args...)

	// Prevent bw from ever reading the TUI's stdin (it prompts for password
	// when session is invalid, which would hang the UI).
	cmd.Stdin = nil // nil = /dev/null
	cmd.Stderr = new(strings.Builder)

	if c.Session != "" {
		// Filter out any existing BW_SESSION from parent env so ours takes
		// precedence (on Linux the first duplicate key wins with execve).
		filtered := make([]string, 0, len(os.Environ()))
		for _, e := range os.Environ() {
			if !strings.HasPrefix(e, "BW_SESSION=") {
				filtered = append(filtered, e)
			}
		}
		cmd.Env = append(filtered, "BW_SESSION="+c.Session)
	}

	out, err := cmd.Output()
	if err != nil {
		stderr := strings.TrimSpace(cmd.Stderr.(*strings.Builder).String())

		// Timeout: bw tried to prompt interactively (stale/invalid session)
		if ctx.Err() == context.DeadlineExceeded {
			return nil, fmt.Errorf("bw %s: timeout (vault may be locked)", strings.Join(args, " "))
		}

		if exitErr, ok := err.(*exec.ExitError); ok {
			msg := stderr
			if msg == "" {
				msg = strings.TrimSpace(string(exitErr.Stderr))
			}
			// Only keep first meaningful line (strip Node.js stack traces)
			if idx := strings.Index(msg, "\n"); idx > 0 {
				first := strings.TrimSpace(msg[:idx])
				if strings.Contains(first, "Error:") || strings.Contains(first, "failed:") {
					msg = first
				}
			}
			return nil, fmt.Errorf("bw %s failed: %s", strings.Join(args, " "), msg)
		}
		return nil, fmt.Errorf("bw %s: %w", strings.Join(args, " "), err)
	}
	return out, nil
}

func (c *Client) ListItems() ([]VaultItem, error) {
	out, err := c.run("list", "items")
	if err != nil {
		return nil, err
	}
	var items []VaultItem
	if err := json.Unmarshal(out, &items); err != nil {
		return nil, fmt.Errorf("parse items: %w", err)
	}
	return items, nil
}

func (c *Client) GetPassword(id string) (string, error) {
	out, err := c.run("get", "password", id)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func (c *Client) GetItem(id string) (*VaultItem, error) {
	out, err := c.run("get", "item", id)
	if err != nil {
		return nil, err
	}
	var item VaultItem
	if err := json.Unmarshal(out, &item); err != nil {
		return nil, fmt.Errorf("parse item: %w", err)
	}
	return &item, nil
}

func (c *Client) Sync() error {
	_, err := c.run("sync")
	return err
}

func (c *Client) Status() (string, error) {
	out, err := c.run("status")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func (c *Client) Unlock(password string) (string, error) {
	cmd := exec.Command(c.BwPath, "unlock", "--raw", "--passwordenv", "BW_PASS")
	cmd.Env = append(cmd.Environ(), "BW_PASS="+password)
	out, err := cmd.Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return "", fmt.Errorf("unlock: %s", strings.TrimSpace(string(exitErr.Stderr)))
		}
		return "", fmt.Errorf("unlock: %w", err)
	}
	return strings.TrimSpace(string(out)), nil
}

func (c *Client) Lock() error {
	_, err := c.run("lock")
	return err
}

func (c *Client) Login(clientID, clientSecret string) error {
	cmd := exec.Command(c.BwPath, "login", "--apikey")
	cmd.Env = append(cmd.Environ(),
		"BW_CLIENTID="+clientID,
		"BW_CLIENTSECRET="+clientSecret,
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("login: %s", strings.TrimSpace(string(out)))
	}
	return nil
}

func (c *Client) Logout() error {
	_, err := c.run("logout")
	return err
}
