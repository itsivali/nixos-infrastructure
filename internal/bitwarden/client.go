package bitwarden

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

type Client struct {
	BwPath  string
	Session string
}

func NewClient(bwPath, session string) *Client {
	return &Client{BwPath: bwPath, Session: session}
}

func (c *Client) run(args ...string) ([]byte, error) {
	cmd := exec.Command(c.BwPath, args...)
	if c.Session != "" {
		cmd.Env = append(cmd.Environ(), "BW_SESSION="+c.Session)
	}
	out, err := cmd.Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("bw %s failed: %s", strings.Join(args, " "),
				strings.TrimSpace(string(exitErr.Stderr)))
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
