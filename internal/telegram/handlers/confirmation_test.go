package handlers

import (
	"testing"
	"time"
)

func TestConfirmationStoreUserBound(t *testing.T) {
	store := NewConfirmationStore()

	store.Request(100, 1, "deploy")
	if !store.ValidateAndConsume(100, 1, "deploy") {
		t.Error("expected owner to confirm their own prompt")
	}
	// One-shot: consuming again must fail.
	if store.ValidateAndConsume(100, 1, "deploy") {
		t.Error("expected one-shot confirmation to be consumed")
	}
}

func TestConfirmationStoreRejectsOtherUser(t *testing.T) {
	store := NewConfirmationStore()

	store.Request(100, 1, "reboot")
	if store.ValidateAndConsume(200, 1, "reboot") {
		t.Error("expected a different user to be rejected")
	}
	// The original user must still be able to confirm.
	if !store.ValidateAndConsume(100, 1, "reboot") {
		t.Error("expected the originating user to confirm")
	}
}

func TestConfirmationStoreExpiry(t *testing.T) {
	store := NewConfirmationStore()

	store.Request(100, 1, "gc")
	// Manually age the entry past the TTL.
	store.mu.Lock()
	for k, c := range store.pending {
		c.expiresAt = time.Now().Add(-time.Second)
		store.pending[k] = c
	}
	store.mu.Unlock()

	if store.ValidateAndConsume(100, 1, "gc") {
		t.Error("expected an expired confirmation to be rejected")
	}
}

func TestConfirmationStoreCancelAll(t *testing.T) {
	store := NewConfirmationStore()

	store.Request(100, 1, "deploy")
	store.Request(100, 1, "rollback")
	store.CancelAll(100, 1)

	if store.ValidateAndConsume(100, 1, "deploy") {
		t.Error("expected deploy confirmation to be cancelled")
	}
	if store.ValidateAndConsume(100, 1, "rollback") {
		t.Error("expected rollback confirmation to be cancelled")
	}
}

func TestConfirmationStoreCancelScopedToUser(t *testing.T) {
	store := NewConfirmationStore()

	store.Request(100, 1, "deploy")
	store.Request(200, 1, "deploy")
	store.CancelAll(100, 1)

	if store.ValidateAndConsume(100, 1, "deploy") {
		t.Error("expected user 100's confirmation to be cancelled")
	}
	if !store.ValidateAndConsume(200, 1, "deploy") {
		t.Error("expected user 200's confirmation to survive")
	}
}
