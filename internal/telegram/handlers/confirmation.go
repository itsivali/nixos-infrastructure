package handlers

import (
	"fmt"
	"strings"
	"sync"
	"time"
)

// confirmationTTL bounds how long a confirmation prompt stays valid.
const confirmationTTL = 5 * time.Minute

// confirmation records a pending destructive action awaiting the initiating
// user's explicit confirmation.
type confirmation struct {
	userID    int
	chatID    int64
	action    string
	expiresAt time.Time
}

// ConfirmationStore tracks pending confirmations keyed by user+chat+action so
// only the originating user can confirm a prompt, and stale prompts expire.
type ConfirmationStore struct {
	mu      sync.Mutex
	pending map[string]confirmation
}

// NewConfirmationStore creates an empty ConfirmationStore.
func NewConfirmationStore() *ConfirmationStore {
	return &ConfirmationStore{pending: make(map[string]confirmation)}
}

func (s *ConfirmationStore) key(userID int, chatID int64, action string) string {
	return fmt.Sprintf("%d:%d:%s", userID, chatID, action)
}

// Request records a pending confirmation for the given user/chat/action.
func (s *ConfirmationStore) Request(userID int, chatID int64, action string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.purgeLocked(time.Now())
	s.pending[s.key(userID, chatID, action)] = confirmation{
		userID:    userID,
		chatID:    chatID,
		action:    action,
		expiresAt: time.Now().Add(confirmationTTL),
	}
}

// ValidateAndConsume checks whether a confirmation for the given
// user/chat/action is pending and unexpired, consuming it in the process so
// each prompt can only confirm once.
func (s *ConfirmationStore) ValidateAndConsume(userID int, chatID int64, action string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	s.purgeLocked(now)

	key := s.key(userID, chatID, action)
	c, ok := s.pending[key]
	if !ok {
		return false
	}
	delete(s.pending, key)
	return now.Before(c.expiresAt)
}

// CancelAll clears every pending confirmation for a user in a chat (used by
// the /cancel command and the cancel button).
func (s *ConfirmationStore) CancelAll(userID int, chatID int64) {
	s.mu.Lock()
	defer s.mu.Unlock()

	prefix := fmt.Sprintf("%d:%d:", userID, chatID)
	for key := range s.pending {
		if strings.HasPrefix(key, prefix) {
			delete(s.pending, key)
		}
	}
}

// purgeLocked removes expired entries; caller must hold the mutex.
func (s *ConfirmationStore) purgeLocked(now time.Time) {
	for key, c := range s.pending {
		if !now.Before(c.expiresAt) {
			delete(s.pending, key)
		}
	}
}

// confirmationStore is the process-wide store used by sendConfirm and the
// confirmHandler in cmd/ivali-bot.
var confirmationStore = NewConfirmationStore()

// RequestConfirmation records a pending confirmation for a user/chat/action.
func RequestConfirmation(userID int, chatID int64, action string) {
	confirmationStore.Request(userID, chatID, action)
}

// ConsumeConfirmation validates and consumes a pending confirmation.
func ConsumeConfirmation(userID int, chatID int64, action string) bool {
	return confirmationStore.ValidateAndConsume(userID, chatID, action)
}

// CancelConfirmations clears pending confirmations for a user in a chat.
func CancelConfirmations(userID int, chatID int64) {
	confirmationStore.CancelAll(userID, chatID)
}
