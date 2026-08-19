package bitwarden

import (
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func TestApplyFilterCategoryAndText(t *testing.T) {
	env := &Env{}
	m := NewTUI(env, "")
	m.list.items = []VaultItem{
		{
			ID:   "1",
			Name: "GitHub",
			Type: 1,
			Login: &Login{
				Username: "octocat",
				Uris:     []URI{{URI: "https://github.com"}},
			},
			Favorite: true,
		},
		{
			ID:   "2",
			Name: "Credit Card",
			Type: 2,
			Card: &Card{
				Brand: "Visa",
			},
		},
		{
			ID:    "3",
			Name:  "Secret Note",
			Type:  4,
			Notes: "top secret instructions",
		},
	}

	// 1. All tab with empty filter
	m.list.activeTab = tabAll
	m.list.filter = nil
	m.applyFilter()
	if len(m.list.filtered) != 3 {
		t.Errorf("expected 3 items in All tab, got %d", len(m.list.filtered))
	}

	// 2. Search for "github"
	m.list.filter = []rune("github")
	m.applyFilter()
	if len(m.list.filtered) != 1 || m.list.filtered[0].Name != "GitHub" {
		t.Errorf("expected GitHub item for 'github' query, got %v", m.list.filtered)
	}

	// 3. Search by notes "top secret"
	m.list.filter = []rune("top secret")
	m.applyFilter()
	if len(m.list.filtered) != 1 || m.list.filtered[0].Name != "Secret Note" {
		t.Errorf("expected Secret Note item for 'top secret' query, got %v", m.list.filtered)
	}

	// 4. Favorites tab
	m.list.filter = nil
	m.list.activeTab = tabFavorites
	m.applyFilter()
	if len(m.list.filtered) != 1 || m.list.filtered[0].Name != "GitHub" {
		t.Errorf("expected 1 favorite item (GitHub), got %d", len(m.list.filtered))
	}
}

func TestVaultItemIconsAndLabels(t *testing.T) {
	loginItem := VaultItem{Type: 1}
	cardItem := VaultItem{Type: 2}
	noteItem := VaultItem{Type: 4}

	if loginItem.Icon() != "🔑" || loginItem.TypeLabel() != "Login" {
		t.Errorf("unexpected login icon/label: %s / %s", loginItem.Icon(), loginItem.TypeLabel())
	}
	if cardItem.Icon() != "💳" || cardItem.TypeLabel() != "Card" {
		t.Errorf("unexpected card icon/label: %s / %s", cardItem.Icon(), cardItem.TypeLabel())
	}
	if noteItem.Icon() != "📝" || noteItem.TypeLabel() != "Note" {
		t.Errorf("unexpected note icon/label: %s / %s", noteItem.Icon(), noteItem.TypeLabel())
	}
}

func keyMsg(key string) tea.KeyMsg {
	return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(key)}
}

func TestUnlockSopsKey(t *testing.T) {
	m := NewTUI(&Env{}, "")
	m.mode = modeUnlock
	m.unlock = &unlockModel{
		status:      "locked",
		activeField: 1,
		hasSopsPass: true,
	}

	for _, key := range []string{"s", "S"} {
		m.unlock.unlocking = false
		m.unlock.err = ""
		_, cmd := m.handleKey(keyMsg(key))

		if !m.unlock.unlocking {
			t.Errorf("pressing %q with SOPS pass should trigger unlock, unlocking=%v", key, m.unlock.unlocking)
		}
		if cmd == nil {
			t.Errorf("pressing %q with SOPS pass should return an unlock command", key)
		}
		if len(m.unlock.password) != 0 {
			t.Errorf("pressing %q with SOPS pass should not type into the password field, password=%q", key, string(m.unlock.password))
		}
	}
}

func TestUnlockShiftSTypesWithoutSopsPass(t *testing.T) {
	m := NewTUI(&Env{}, "")
	m.mode = modeUnlock
	m.unlock = &unlockModel{
		status:      "locked",
		activeField: 1,
		hasSopsPass: false,
	}

	_, cmd := m.handleKey(keyMsg("S"))

	if m.unlock.unlocking {
		t.Errorf("pressing %q without a SOPS pass should not trigger unlock", "S")
	}
	if cmd != nil {
		t.Errorf("pressing %q without a SOPS pass should not return an unlock command", "S")
	}
	if string(m.unlock.password) != "S" {
		t.Errorf("pressing %q without a SOPS pass should type into the password field, password=%q", "S", string(m.unlock.password))
	}
}
