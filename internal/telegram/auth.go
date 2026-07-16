package telegram

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

// Auth manages user authentication and authorization.
type Auth struct {
	mu       sync.RWMutex
	users    map[int]*UserAuth
	filePath string
}

// UserAuth represents an authenticated user.
type UserAuth struct {
	Role  Role   `json:"role"`
	Name  string `json:"name"`
	Added string `json:"added,omitempty"`
}

// NewAuth creates a new Auth instance.
func NewAuth(stateDir string) *Auth {
	filePath := filepath.Join(stateDir, "auth.json")
	a := &Auth{
		users:    make(map[int]*UserAuth),
		filePath: filePath,
	}
	a.load()
	return a
}

// GetUserRole returns the role for a user. If no auth file exists or the user
// is not found, returns RoleOwner (single-user mode).
func (a *Auth) GetUserRole(userID int) Role {
	a.mu.RLock()
	defer a.mu.RUnlock()

	// If no users are configured, everyone is owner (single-user mode)
	if len(a.users) == 0 {
		return RoleOwner
	}

	if user, ok := a.users[userID]; ok {
		return user.Role
	}

	return RoleGuest
}

// CheckPermission checks if a user has the required role.
func (a *Auth) CheckPermission(userID int, required Role) bool {
	return a.GetUserRole(userID).HasPermission(required)
}

// AddUser adds or updates a user's role.
func (a *Auth) AddUser(userID int, role Role, name string) {
	a.mu.Lock()
	defer a.mu.Unlock()

	a.users[userID] = &UserAuth{
		Role: role,
		Name: name,
	}
	a.save()
}

// RemoveUser removes a user.
func (a *Auth) RemoveUser(userID int) {
	a.mu.Lock()
	defer a.mu.Unlock()

	delete(a.users, userID)
	a.save()
}

// ListUsers returns all configured users.
func (a *Auth) ListUsers() map[int]*UserAuth {
	a.mu.RLock()
	defer a.mu.RUnlock()

	result := make(map[int]*UserAuth, len(a.users))
	for k, v := range a.users {
		result[k] = v
	}
	return result
}

// authFile is the on-disk format for the auth file.
type authFile struct {
	Users map[string]*UserAuth `json:"users"`
}

// load reads the auth file from disk.
func (a *Auth) load() {
	data, err := os.ReadFile(a.filePath)
	if err != nil {
		return
	}

	var file authFile
	if err := json.Unmarshal(data, &file); err != nil {
		return
	}

	for idStr, user := range file.Users {
		var id int
		if _, err := fmt.Sscanf(idStr, "%d", &id); err != nil {
			continue
		}
		a.users[id] = user
	}
}

// save writes the auth file to disk.
func (a *Auth) save() {
	file := authFile{
		Users: make(map[string]*UserAuth, len(a.users)),
	}

	for id, user := range a.users {
		file.Users[fmt.Sprintf("%d", id)] = user
	}

	data, err := json.MarshalIndent(file, "", "  ")
	if err != nil {
		return
	}

	dir := filepath.Dir(a.filePath)
	os.MkdirAll(dir, 0o755)
	os.WriteFile(a.filePath, data, 0o600)
}
