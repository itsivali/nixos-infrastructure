package handlers

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// AuthStatusCommand shows the current authentication mode and how to register
// users. In single-user mode (no users configured) every member of the
// authorised chat is treated as owner; once /grant registers a user, the
// fallback is disabled and only registered users have roles.
type AuthStatusCommand struct {
	auth *telegram.Auth
	api  *telegram.API
}

func NewAuthStatusCommand(auth *telegram.Auth, api *telegram.API) *AuthStatusCommand {
	return &AuthStatusCommand{auth: auth, api: api}
}

func (c *AuthStatusCommand) Name() string                      { return "auth" }
func (c *AuthStatusCommand) Description() string               { return "Show authentication status" }
func (c *AuthStatusCommand) RequiredPermission() telegram.Role { return telegram.RoleGuest }

func (c *AuthStatusCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	users := c.auth.ListUsers()
	var b strings.Builder
	b.WriteString("*Authentication*\n\n")
	if len(users) == 0 {
		b.WriteString("Single-user mode: every member of the authorised chat is currently treated as *owner*.\n\n")
		b.WriteString("Register the first user to lock this down:\n")
		b.WriteString("`/grant <userId> <role>` — e.g. `/grant 123456 owner`\n")
		b.WriteString("`/grant <role>` — grant your own user ID that role\n")
		b.WriteString("Roles: owner, admin, user, guest")
	} else {
		b.WriteString(fmt.Sprintf("%d user(s) registered. Unknown users are *guest*.\n\n", len(users)))
		b.WriteString("`/grant <userId> <role>` — add or update a user\n")
		b.WriteString("`/revoke <userId>` — remove a user\n")
		b.WriteString("`/users` — list registered users")
	}
	return c.api.SendMarkdown(msg.ChatID, b.String())
}

// GrantCommand adds or updates a user's role. Owner only.
type GrantCommand struct {
	auth *telegram.Auth
	api  *telegram.API
}

func NewGrantCommand(auth *telegram.Auth, api *telegram.API) *GrantCommand {
	return &GrantCommand{auth: auth, api: api}
}

func (c *GrantCommand) Name() string                      { return "grant" }
func (c *GrantCommand) Description() string               { return "Grant a user a role" }
func (c *GrantCommand) RequiredPermission() telegram.Role { return telegram.RoleOwner }

func (c *GrantCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	fields := strings.Fields(msg.Args)
	var userID int
	var role telegram.Role

	switch len(fields) {
	case 1:
		// Grant the issuing user a role: /grant <role>
		userID = msg.UserID
		role = telegram.ParseRole(fields[0])
	case 2:
		// /grant <userId> <role>
		id, err := strconv.Atoi(fields[0])
		if err != nil {
			return c.api.SendMarkdown(msg.ChatID, "Usage: `/grant <userId> <role>` or `/grant <role>`")
		}
		userID = id
		role = telegram.ParseRole(fields[1])
	default:
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/grant <userId> <role>` or `/grant <role>`")
	}

	if role == telegram.RoleGuest {
		return c.api.SendMarkdown(msg.ChatID, "Use a real role: owner, admin, user.")
	}

	c.auth.AddUser(userID, role, msg.Username)
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Granted *%s* to user `%d` (`%s`).", role, userID, msg.Username))
}

// RevokeCommand removes a user. Owner only.
type RevokeCommand struct {
	auth *telegram.Auth
	api  *telegram.API
}

func NewRevokeCommand(auth *telegram.Auth, api *telegram.API) *RevokeCommand {
	return &RevokeCommand{auth: auth, api: api}
}

func (c *RevokeCommand) Name() string                      { return "revoke" }
func (c *RevokeCommand) Description() string               { return "Revoke a user's access" }
func (c *RevokeCommand) RequiredPermission() telegram.Role { return telegram.RoleOwner }

func (c *RevokeCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	fields := strings.Fields(msg.Args)
	if len(fields) != 1 {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/revoke <userId>`")
	}
	id, err := strconv.Atoi(fields[0])
	if err != nil {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/revoke <userId>` (numeric user ID)")
	}
	c.auth.RemoveUser(id)
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Revoked access for user `%d`.", id))
}

// UsersListCommand lists registered users.
type UsersListCommand struct {
	auth *telegram.Auth
	api  *telegram.API
}

func NewUsersListCommand(auth *telegram.Auth, api *telegram.API) *UsersListCommand {
	return &UsersListCommand{auth: auth, api: api}
}

func (c *UsersListCommand) Name() string                      { return "users" }
func (c *UsersListCommand) Description() string               { return "List registered users" }
func (c *UsersListCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *UsersListCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	users := c.auth.ListUsers()
	if len(users) == 0 {
		return c.api.SendMarkdown(msg.ChatID, "No users registered — single-user mode (chat members are owner).")
	}
	var b strings.Builder
	b.WriteString("*Registered users*\n\n")
	for id, u := range users {
		name := u.Name
		if name == "" {
			name = "unknown"
		}
		b.WriteString(fmt.Sprintf("• `%d` — *%s* (`%s`)\n", id, name, u.Role))
	}
	return c.api.SendMarkdown(msg.ChatID, b.String())
}
