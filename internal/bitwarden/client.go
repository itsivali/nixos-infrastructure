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

	// Use /dev/null for stdin so bw gets EOF immediately instead of reading
	// the TUI's stdin (which would cause it to prompt for password
	// interactively and hang the UI). nil maps to os.DevNull in Go's exec.
	cmd.Stdin = nil

	stderr := new(strings.Builder)
	cmd.Stderr = stderr

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

	// Timeout: bw tried to prompt interactively (stale/invalid session)
	if ctx.Err() == context.DeadlineExceeded {
		return nil, fmt.Errorf("bw %s: timeout (vault may be locked)", strings.Join(args, " "))
	}

	if err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			// Some bw errors go to stdout (exit code 1, no stderr written)
			msg = strings.TrimSpace(string(out))
		}
		if msg == "" {
			msg = err.Error()
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

	// bw sometimes exits 0 with empty/whitespace output (e.g. when session
	// is invalid but bw doesn't classify it as an error)
	if len(strings.TrimSpace(string(out))) == 0 {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = "empty response (vault may be locked)"
		}
		return nil, fmt.Errorf("bw %s: %s", strings.Join(args, " "), msg)
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
		snippet := strings.TrimSpace(string(out))
		if len(snippet) > 120 {
			snippet = snippet[:120] + "..."
		}
		return nil, fmt.Errorf("parse items: %w (got: %q)", err, snippet)
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
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, c.BwPath, "unlock", "--raw", "--passwordenv", "BW_PASS")
	cmd.Stdin = nil
	stderr := new(strings.Builder)
	cmd.Stderr = stderr
	cmd.Env = append(cmd.Environ(), "BW_PASS="+password)
	out, err := cmd.Output()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return "", fmt.Errorf("unlock: timeout")
		}
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = "unlock failed"
		}
		return "", fmt.Errorf("unlock: %s", msg)
	}
	return strings.TrimSpace(string(out)), nil
}

func (c *Client) Lock() error {
	_, err := c.run("lock")
	return err
}

func (c *Client) Login(clientID, clientSecret string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, c.BwPath, "login", "--apikey")
	cmd.Stdin = nil
	cmd.Env = append(cmd.Environ(),
		"BW_CLIENTID="+clientID,
		"BW_CLIENTSECRET="+clientSecret,
	)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return fmt.Errorf("login: timeout")
		}
		return fmt.Errorf("login: %s", strings.TrimSpace(string(out)))
	}
	return nil
}

func (c *Client) Logout() error {
	_, err := c.run("logout")
	return err
}
