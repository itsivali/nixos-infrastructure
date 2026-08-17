package bitwarden

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ── Styling (Catppuccin Mocha) ─────────────────────────────

var (
	clrCrust   = lipgloss.Color("#11111b")
	clrSurface = lipgloss.Color("#313244")
	clrOverlay = lipgloss.Color("#45475a")
	clrDim     = lipgloss.Color("#6c7086")
	clrText    = lipgloss.Color("#cdd6f4")
	clrAccent  = lipgloss.Color("#89b4fa")
	clrGreen   = lipgloss.Color("#a6e3a1")
	clrRed     = lipgloss.Color("#f38ba8")
	clrYellow  = lipgloss.Color("#f9e2af")
	clrMauve   = lipgloss.Color("#cba6f7")

	styleTitleBar = lipgloss.NewStyle().
			Foreground(clrCrust).
			Background(clrAccent).
			Bold(true).
			Padding(0, 1)

	styleTabActive = lipgloss.NewStyle().
			Foreground(clrCrust).
			Background(clrMauve).
			Bold(true).
			Padding(0, 1)

	styleTabInactive = lipgloss.NewStyle().
				Foreground(clrText).
				Background(clrSurface).
				Padding(0, 1)

	styleItem = lipgloss.NewStyle().
			Padding(0, 2)

	styleSelected = lipgloss.NewStyle().
			Foreground(clrText).
			Background(clrSurface).
			Bold(true).
			Padding(0, 2)

	styleDim = lipgloss.NewStyle().
			Foreground(clrDim).
			Padding(0, 2)

	styleDetailLabel = lipgloss.NewStyle().
				Foreground(clrMauve).
				Bold(true).
				Width(11).
				Align(lipgloss.Right)

	styleDetailValue = lipgloss.NewStyle().
				Foreground(clrText).
				Padding(0, 0, 0, 1)

	styleCopied = lipgloss.NewStyle().
			Foreground(clrGreen).
			Bold(true)

	styleKey = lipgloss.NewStyle().
			Foreground(clrAccent).
			Bold(true)

	styleStatusBar = lipgloss.NewStyle().
			Foreground(clrText).
			Background(clrOverlay).
			Padding(0, 1)

	styleBox = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(clrMauve).
			Padding(1, 2)
)

// ── Messages ──────────────────────────────────────────────

type passwordMsg struct {
	password string
}

type passwordErrMsg struct {
	err error
}

type itemsLoadedMsg struct {
	items []VaultItem
}

type itemsErrMsg struct {
	err error
}

type syncDoneMsg struct{}

type syncErrMsg struct {
	err error
}

type unlockSuccessMsg struct {
	session string
}

type unlockErrMsg struct {
	err error
}

// ── Model Definitions ─────────────────────────────────────

type viewMode int

const (
	modeList viewMode = iota
	modeDetail
	modeUnlock
)

type categoryTab int

const (
	tabAll categoryTab = iota
	tabLogins
	tabCards
	tabNotes
	tabFavorites
)

func (c categoryTab) String() string {
	switch c {
	case tabAll:
		return "All"
	case tabLogins:
		return "Logins"
	case tabCards:
		return "Cards"
	case tabNotes:
		return "Notes"
	case tabFavorites:
		return "Favorites"
	default:
		return "All"
	}
}

type unlockModel struct {
	status      string // "unauthenticated" or "locked"
	email       []rune
	password    []rune
	activeField int // 0 = email (if unauthenticated), 1 = password
	err         string
	unlocking   bool
	hasSopsPass bool
	sopsPass    string
}

type detailModel struct {
	item         VaultItem
	password     string
	showPassword bool
	fetching     bool
	copiedField  string
	copiedAt     time.Time
	err          string
	status       string
	statusAt     time.Time
}

type listModel struct {
	items     []VaultItem
	filtered  []VaultItem
	cursor    int
	offset    int
	filter    []rune
	activeTab categoryTab
}

type tuiModel struct {
	mode  viewMode
	state string // "loading", "unlocked", "locked", "unauthenticated", "error"

	width  int
	height int

	list   listModel
	detail *detailModel
	unlock *unlockModel

	client *Client
	env    *Env

	cacheFile     string
	cacheTimeFile string
	cacheTTL      time.Duration
	sessionFile   string

	initialFilter string

	toast   string
	toastAt time.Time

	err     error
	errTime time.Time
}

type Env struct {
	BwPath        string
	Session       string
	SessionFile   string
	CacheFile     string
	CacheTimeFile string
	CacheTTL      time.Duration
}

func DefaultEnv() *Env {
	return &Env{
		BwPath:        FindBwPath(),
		Session:       "",
		SessionFile:   os.Getenv("BW_SESSION_FILE"),
		CacheFile:     os.Getenv("BW_CACHE_FILE"),
		CacheTimeFile: os.Getenv("BW_CACHE_TIME"),
		CacheTTL:      5 * time.Minute,
	}
}

func (e *Env) Resolve() {
	if e.SessionFile == "" {
		rtDir := os.Getenv("BW_RT_DIR")
		if rtDir == "" {
			xdgRun := os.Getenv("XDG_RUNTIME_DIR")
			if xdgRun == "" {
				xdgRun = "/run/user/1000"
			}
			rtDir = xdgRun + "/bitwarden"
		}
		e.SessionFile = rtDir + "/session"
	}
	if e.CacheFile == "" {
		rtDir := os.Getenv("BW_RT_DIR")
		if rtDir == "" {
			xdgRun := os.Getenv("XDG_RUNTIME_DIR")
			if xdgRun == "" {
				xdgRun = "/run/user/1000"
			}
			rtDir = xdgRun + "/bitwarden"
		}
		e.CacheFile = rtDir + "/cache.json"
	}
	if e.CacheTimeFile == "" {
		rtDir := os.Getenv("BW_RT_DIR")
		if rtDir == "" {
			xdgRun := os.Getenv("XDG_RUNTIME_DIR")
			if xdgRun == "" {
				xdgRun = "/run/user/1000"
			}
			rtDir = xdgRun + "/bitwarden"
		}
		e.CacheTimeFile = rtDir + "/cache-time"
	}
	if e.Session == "" {
		if session, err := ReadSessionFromFile(e.SessionFile); err == nil {
			e.Session = session
		}
	}
}

func NewTUI(env *Env, initialFilter string) *tuiModel {
	env.Resolve()
	m := &tuiModel{
		mode:          modeList,
		state:         "loading",
		env:           env,
		cacheFile:     env.CacheFile,
		cacheTimeFile: env.CacheTimeFile,
		cacheTTL:      env.CacheTTL,
		sessionFile:   env.SessionFile,
		initialFilter: initialFilter,
	}
	m.client = NewClient(env.BwPath, "")
	return m
}

func (m *tuiModel) Init() tea.Cmd {
	if m.env.Session != "" {
		m.client.Session = m.env.Session
	} else if session, err := ReadSessionFromFile(m.sessionFile); err == nil && session != "" {
		m.client.Session = session
		m.env.Session = session
	}
	return m.loadItems()
}

func (m *tuiModel) initUnlockModel() {
	status, _ := m.client.GetVaultStatus()
	if status == "" || status == "unknown" {
		status = "locked"
	}

	m.unlock = &unlockModel{
		status:      status,
		activeField: 0,
	}

	if status == "unauthenticated" {
		m.unlock.activeField = 0
	} else {
		m.unlock.activeField = 1
	}

	// Read SOPS password if present
	sopsPassPath := "/run/secrets/bitwarden_password"
	if data, err := os.ReadFile(sopsPassPath); err == nil && len(strings.TrimSpace(string(data))) > 0 {
		m.unlock.hasSopsPass = true
		m.unlock.sopsPass = strings.TrimSpace(string(data))
	}

	// Read SOPS email if present
	sopsEmailPath := "/run/secrets/bitwarden_email"
	if data, err := os.ReadFile(sopsEmailPath); err == nil && len(strings.TrimSpace(string(data))) > 0 {
		m.unlock.email = []rune(strings.TrimSpace(string(data)))
	}
}

func (m *tuiModel) loadItems() tea.Cmd {
	return func() tea.Msg {
		var items []VaultItem
		var err error

		if m.cacheFile != "" {
			items, err = ReadCache(m.cacheFile)
			if err == nil && len(items) > 0 {
				m.state = "unlocked"
				return itemsLoadedMsg{items: items}
			}
		}

		items, err = m.client.ListItems()
		if err != nil {
			status, _ := m.client.GetVaultStatus()
			if status == "unauthenticated" {
				m.state = "unauthenticated"
			} else {
				m.state = "locked"
			}
			return itemsErrMsg{err: err}
		}
		if m.cacheFile != "" {
			_ = WriteCache(m.cacheFile, items)
			_ = WriteCacheTime(m.cacheTimeFile)
		}
		m.state = "unlocked"
		return itemsLoadedMsg{items: items}
	}
}

func (m *tuiModel) applyFilter() {
	filter := strings.ToLower(string(m.list.filter))
	m.list.filtered = nil

	for _, item := range m.list.items {
		// Category tab filter
		switch m.list.activeTab {
		case tabLogins:
			if item.Type != 1 {
				continue
			}
		case tabCards:
			if item.Type != 2 {
				continue
			}
		case tabNotes:
			if item.Type != 4 {
				continue
			}
		case tabFavorites:
			if !item.Favorite {
				continue
			}
		}

		// Text search across fields
		if filter == "" {
			m.list.filtered = append(m.list.filtered, item)
		} else {
			if strings.Contains(strings.ToLower(item.Name), filter) ||
				strings.Contains(strings.ToLower(item.Username()), filter) ||
				strings.Contains(strings.ToLower(item.PrimaryURI()), filter) ||
				strings.Contains(strings.ToLower(item.Notes), filter) {
				m.list.filtered = append(m.list.filtered, item)
			}
		}
	}

	if m.list.cursor >= len(m.list.filtered) {
		m.list.cursor = len(m.list.filtered) - 1
		if m.list.cursor < 0 {
			m.list.cursor = 0
		}
	}
}

func (m *tuiModel) showToast(msg string) {
	m.toast = msg
	m.toastAt = time.Now()
}

func (m *tuiModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height

	case tea.KeyMsg:
		return m.handleKey(msg)

	case itemsLoadedMsg:
		m.list.items = msg.items
		m.applyFilter()
		if m.initialFilter != "" {
			m.list.filter = []rune(m.initialFilter)
			m.applyFilter()
			m.initialFilter = ""
		}
		m.state = "unlocked"
		m.mode = modeList
		return m, nil

	case itemsErrMsg:
		m.err = msg.err
		m.errTime = time.Now()
		m.mode = modeUnlock
		m.initUnlockModel()
		return m, nil

	case unlockSuccessMsg:
		m.env.Session = msg.session
		m.client.Session = msg.session
		_ = WriteSessionFile(m.sessionFile, msg.session)
		m.state = "unlocked"
		m.mode = modeList
		m.showToast("Vault Logged In & Unlocked Successfully!")
		return m, m.reloadItems()

	case unlockErrMsg:
		if m.unlock != nil {
			m.unlock.unlocking = false
			m.unlock.err = msg.err.Error()
		}
		return m, nil

	case passwordMsg:
		if m.detail != nil {
			m.detail.password = msg.password
			m.detail.fetching = false
		}
		return m, nil

	case passwordErrMsg:
		if m.detail != nil {
			m.detail.err = msg.err.Error()
			m.detail.fetching = false
		}
		return m, nil

	case syncDoneMsg:
		m.showToast("Vault Synced!")
		return m, m.loadItems()

	case syncErrMsg:
		m.err = msg.err
		m.errTime = time.Now()
		return m, nil
	}

	return m, nil
}

func (m *tuiModel) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch m.mode {
	case modeUnlock:
		return m.handleUnlockKey(msg)
	case modeList:
		return m.handleListKey(msg)
	case modeDetail:
		return m.handleDetailKey(msg)
	}
	return m, nil
}

func (m *tuiModel) handleUnlockKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	if m.unlock == nil {
		m.initUnlockModel()
	}

	switch msg.String() {
	case "ctrl+c", "esc":
		return m, tea.Quit

	case "tab", "down", "up":
		if m.unlock.status == "unauthenticated" {
			if m.unlock.activeField == 0 {
				m.unlock.activeField = 1
			} else {
				m.unlock.activeField = 0
			}
		}

	case "backspace":
		if m.unlock.activeField == 0 && len(m.unlock.email) > 0 {
			m.unlock.email = m.unlock.email[:len(m.unlock.email)-1]
		} else if len(m.unlock.password) > 0 {
			m.unlock.password = m.unlock.password[:len(m.unlock.password)-1]
		}

	case "enter":
		if !m.unlock.unlocking {
			if m.unlock.status == "unauthenticated" && len(m.unlock.email) == 0 {
				m.unlock.err = "Please enter your Bitwarden email address"
				return m, nil
			}
			if len(m.unlock.password) == 0 {
				m.unlock.err = "Please enter your master password"
				return m, nil
			}
			m.unlock.unlocking = true
			m.unlock.err = ""
			return m, m.performLoginAndUnlock(string(m.unlock.email), string(m.unlock.password))
		}

	case "s":
		if m.unlock.hasSopsPass && !m.unlock.unlocking {
			m.unlock.unlocking = true
			m.unlock.err = ""
			return m, m.performLoginAndUnlock(string(m.unlock.email), m.unlock.sopsPass)
		} else if !m.unlock.unlocking && isPrintableKey(msg) {
			if m.unlock.activeField == 0 && m.unlock.status == "unauthenticated" {
				m.unlock.email = append(m.unlock.email, []rune(msg.String())...)
			} else {
				m.unlock.password = append(m.unlock.password, []rune(msg.String())...)
			}
		}

	default:
		if isPrintableKey(msg) && !m.unlock.unlocking {
			if m.unlock.activeField == 0 && m.unlock.status == "unauthenticated" {
				m.unlock.email = append(m.unlock.email, []rune(msg.String())...)
			} else {
				m.unlock.password = append(m.unlock.password, []rune(msg.String())...)
			}
		}
	}
	return m, nil
}

func (m *tuiModel) performLoginAndUnlock(email, password string) tea.Cmd {
	return func() tea.Msg {
		session, err := m.client.LoginAndUnlock(email, password, "", "")
		if err != nil {
			return unlockErrMsg{err: err}
		}
		return unlockSuccessMsg{session: session}
	}
}

func (m *tuiModel) handleListKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit

	case "tab":
		m.list.activeTab = (m.list.activeTab + 1) % 5
		m.list.cursor = 0
		m.applyFilter()

	case "shift+tab":
		m.list.activeTab = (m.list.activeTab + 4) % 5
		m.list.cursor = 0
		m.applyFilter()

	case "1", "2", "3", "4", "5":
		if len(m.list.filter) == 0 {
			idx := int(msg.String()[0] - '1')
			m.list.activeTab = categoryTab(idx)
			m.list.cursor = 0
			m.applyFilter()
			return m, nil
		} else if isPrintableKey(msg) {
			m.list.filter = append(m.list.filter, []rune(msg.String())...)
			m.applyFilter()
		}

	case "up", "k":
		if m.list.cursor > 0 {
			m.list.cursor--
		}

	case "down", "j":
		if m.list.cursor < len(m.list.filtered)-1 {
			m.list.cursor++
		}

	case "pgup":
		m.list.cursor -= m.scrollPage()
		if m.list.cursor < 0 {
			m.list.cursor = 0
		}

	case "pgdown":
		m.list.cursor += m.scrollPage()
		if m.list.cursor >= len(m.list.filtered) {
			m.list.cursor = len(m.list.filtered) - 1
		}

	case "home":
		m.list.cursor = 0

	case "end":
		m.list.cursor = len(m.list.filtered) - 1

	case "enter":
		if len(m.list.filtered) > 0 {
			item := m.list.filtered[m.list.cursor]
			m.mode = modeDetail
			m.detail = &detailModel{
				item:         item,
				showPassword: false,
			}
			return m, m.fetchPassword(item.ID)
		}

	case "esc":
		if len(m.list.filter) > 0 {
			m.list.filter = nil
			m.applyFilter()
		} else {
			return m, tea.Quit
		}

	case "backspace":
		if len(m.list.filter) > 0 {
			m.list.filter = m.list.filter[:len(m.list.filter)-1]
			m.applyFilter()
		}

	case "y", "p":
		if len(m.list.filtered) > 0 {
			item := m.list.filtered[m.list.cursor]
			return m, m.quickCopyPassword(item.ID)
		}

	case "u":
		if len(m.list.filtered) > 0 {
			item := m.list.filtered[m.list.cursor]
			u := item.Username()
			if u != "" {
				_ = CopyToClipboard(u)
				SendNotification("Bitwarden TUI", "Username copied to clipboard")
				m.showToast("✓ Username copied!")
			} else {
				m.showToast("No username for selected item")
			}
		}

	case "o":
		if len(m.list.filtered) > 0 {
			item := m.list.filtered[m.list.cursor]
			uri := item.PrimaryURI()
			if uri != "" {
				_ = exec.Command("xdg-open", uri).Start()
				m.showToast("Opened URL in browser!")
			} else {
				m.showToast("No URI for selected item")
			}
		}

	case "r":
		return m, m.reloadItems()

	case "s":
		return m, m.syncVault()

	case "l":
		_ = m.client.Lock()
		m.state = "locked"
		m.mode = modeUnlock
		m.initUnlockModel()
		m.showToast("Vault Locked")
		return m, nil

	default:
		if isPrintableKey(msg) {
			m.list.filter = append(m.list.filter, []rune(msg.String())...)
			m.applyFilter()
		}
	}

	return m, nil
}

func (m *tuiModel) quickCopyPassword(id string) tea.Cmd {
	return func() tea.Msg {
		pass, err := m.client.GetPassword(id)
		if err != nil {
			return itemsErrMsg{err: err}
		}
		_ = CopyToClipboardWithTimeout(pass, 30)
		return passwordMsg{password: pass}
	}
}

func (m *tuiModel) handleDetailKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit

	case "esc", "left", "h":
		m.mode = modeList
		m.detail = nil
		return m, nil

	case "v":
		if m.detail != nil {
			m.detail.showPassword = !m.detail.showPassword
		}

	case "y", "p":
		if m.detail.password == "" {
			m.detail.status = "Password fetching..."
			m.detail.statusAt = time.Now()
			break
		}
		if err := CopyToClipboardWithTimeout(m.detail.password, 30); err != nil {
			m.detail.status = "Clipboard error: " + err.Error()
			m.detail.statusAt = time.Now()
		} else {
			m.detail.copiedField = "password"
			m.detail.copiedAt = time.Now()
			m.detail.status = "✓ Password copied (30s auto-clear)!"
			m.detail.statusAt = time.Now()
		}

	case "u", "e":
		u := m.detail.item.Username()
		if u == "" {
			m.detail.status = "No username for this item"
			m.detail.statusAt = time.Now()
			break
		}
		if err := CopyToClipboard(u); err != nil {
			m.detail.status = "Clipboard error: " + err.Error()
			m.detail.statusAt = time.Now()
		} else {
			SendNotification("Bitwarden TUI", "Username copied to clipboard")
			m.detail.copiedField = "email"
			m.detail.copiedAt = time.Now()
			m.detail.status = "✓ Username copied!"
			m.detail.statusAt = time.Now()
		}

	case "i":
		uri := m.detail.item.PrimaryURI()
		if uri == "" {
			m.detail.status = "No URI for this item"
			m.detail.statusAt = time.Now()
			break
		}
		if err := CopyToClipboard(uri); err != nil {
			m.detail.status = "Clipboard error: " + err.Error()
			m.detail.statusAt = time.Now()
		} else {
			SendNotification("Bitwarden TUI", "URI copied to clipboard")
			m.detail.copiedField = "uri"
			m.detail.copiedAt = time.Now()
			m.detail.status = "✓ URI copied!"
			m.detail.statusAt = time.Now()
		}

	case "n":
		if m.detail.item.Notes == "" {
			m.detail.status = "No notes for this item"
			m.detail.statusAt = time.Now()
			break
		}
		if err := CopyToClipboard(m.detail.item.Notes); err != nil {
			m.detail.status = "Clipboard error: " + err.Error()
			m.detail.statusAt = time.Now()
		} else {
			SendNotification("Bitwarden TUI", "Notes copied to clipboard")
			m.detail.copiedField = "notes"
			m.detail.copiedAt = time.Now()
			m.detail.status = "✓ Notes copied!"
			m.detail.statusAt = time.Now()
		}

	case "o":
		uri := m.detail.item.PrimaryURI()
		if uri == "" {
			m.detail.status = "No URI to open"
			m.detail.statusAt = time.Now()
			break
		}
		if err := exec.Command("xdg-open", uri).Start(); err != nil {
			m.detail.status = "Failed to open browser: " + err.Error()
			m.detail.statusAt = time.Now()
		} else {
			m.detail.status = "Opened in default browser"
			m.detail.statusAt = time.Now()
		}
	}

	return m, nil
}

func (m *tuiModel) fetchPassword(id string) tea.Cmd {
	return func() tea.Msg {
		password, err := m.client.GetPassword(id)
		if err != nil {
			return passwordErrMsg{err: err}
		}
		return passwordMsg{password: password}
	}
}

func (m *tuiModel) reloadItems() tea.Cmd {
	return func() tea.Msg {
		items, err := m.client.ListItems()
		if err != nil {
			return itemsErrMsg{err: err}
		}
		return itemsLoadedMsg{items: items}
	}
}

func (m *tuiModel) syncVault() tea.Cmd {
	return func() tea.Msg {
		if err := m.client.Sync(); err != nil {
			return syncErrMsg{err: err}
		}
		return syncDoneMsg{}
	}
}

func (m *tuiModel) ready() bool { return m.width > 0 && m.height > 0 }

func (m *tuiModel) scrollPage() int {
	return max(1, m.height-6)
}

// ── View Rendering ────────────────────────────────────────

func (m *tuiModel) View() string {
	if !m.ready() {
		return "Loading Bitwarden TUI..."
	}

	switch m.mode {
	case modeUnlock:
		return m.renderUnlock()
	case modeList:
		return m.renderList()
	case modeDetail:
		return m.renderDetail()
	}
	return ""
}

func (m *tuiModel) renderUnlock() string {
	var b strings.Builder

	if m.unlock == nil {
		m.initUnlockModel()
	}

	if m.unlock.status == "unauthenticated" {
		title := styleTitleBar.Render(" 🔑 Bitwarden Vault — Login Required ")
		b.WriteString(title + "\n\n")

		var dialogContent string
		if m.unlock.unlocking {
			dialogContent += "Logging into Bitwarden...\n\n"
		} else {
			emailStr := string(m.unlock.email)
			if m.unlock.activeField == 0 {
				dialogContent += fmt.Sprintf("%s Email: %s█\n\n", styleKey.Render("►"), emailStr)
			} else {
				dialogContent += fmt.Sprintf("  Email: %s\n\n", emailStr)
			}

			maskedPass := strings.Repeat("•", len(m.unlock.password))
			if m.unlock.activeField == 1 {
				dialogContent += fmt.Sprintf("%s Master Password: %s█\n\n", styleKey.Render("►"), maskedPass)
			} else {
				dialogContent += fmt.Sprintf("  Master Password: %s\n\n", maskedPass)
			}

			if m.unlock.hasSopsPass {
				dialogContent += lipgloss.NewStyle().Foreground(clrGreen).Render("✓ SOPS master password detected") + "\n"
				dialogContent += fmt.Sprintf("Press %s to login using SOPS secret\n\n", styleKey.Render("[s]"))
			}

			if m.unlock.err != "" {
				dialogContent += lipgloss.NewStyle().Foreground(clrRed).Render("Error: "+m.unlock.err) + "\n\n"
			}
			dialogContent += "Press [Tab/↑↓] switch field  •  [Enter] submit  •  [Esc] quit"
		}

		box := styleBox.Width(min(65, m.width-4)).Render(dialogContent)
		b.WriteString(box + "\n")
	} else {
		title := styleTitleBar.Render(" 🔐 Bitwarden Vault — Unlock Required ")
		b.WriteString(title + "\n\n")

		var dialogContent string
		masked := strings.Repeat("•", len(m.unlock.password))
		if m.unlock.unlocking {
			dialogContent += "Unlocking vault...\n\n"
		} else {
			dialogContent += fmt.Sprintf("Master Password: %s█\n\n", masked)
			if m.unlock.hasSopsPass {
				dialogContent += lipgloss.NewStyle().Foreground(clrGreen).Render("✓ SOPS master password detected") + "\n"
				dialogContent += fmt.Sprintf("Press %s to unlock using SOPS secret\n\n", styleKey.Render("[s]"))
			}
			if m.unlock.err != "" {
				dialogContent += lipgloss.NewStyle().Foreground(clrRed).Render("Error: "+m.unlock.err) + "\n\n"
			}
			dialogContent += "Press [Enter] to submit  •  [Esc/q] to quit"
		}

		box := styleBox.Width(min(60, m.width-4)).Render(dialogContent)
		b.WriteString(box + "\n")
	}

	return lipgloss.NewStyle().Width(m.width).Render(b.String())
}

func (m *tuiModel) renderCategoryTabs() string {
	var tabs []string
	categories := []categoryTab{tabAll, tabLogins, tabCards, tabNotes, tabFavorites}

	for i, cat := range categories {
		label := fmt.Sprintf("[%d: %s]", i+1, cat.String())
		if cat == m.list.activeTab {
			tabs = append(tabs, styleTabActive.Render(label))
		} else {
			tabs = append(tabs, styleTabInactive.Render(label))
		}
	}
	return strings.Join(tabs, " ")
}

func (m *tuiModel) renderList() string {
	var b strings.Builder

	// Header Title Bar
	titleText := fmt.Sprintf(" BW — Bitwarden Vault    %d items    %s", len(m.list.items), m.stateIcon())
	title := styleTitleBar.Render(titleText)
	b.WriteString(title + "\n")

	// Category Tabs
	b.WriteString(m.renderCategoryTabs() + "\n")

	// Search filter bar
	filterStr := string(m.list.filter)
	if filterStr == "" {
		b.WriteString(lipgloss.NewStyle().Foreground(clrDim).Render(" 🔍 Filter credentials (type to search)...") + "\n\n")
	} else {
		b.WriteString(fmt.Sprintf(" 🔍 Filter: %s    %d matches\n\n",
			lipgloss.NewStyle().Foreground(clrYellow).Bold(true).Render(filterStr),
			len(m.list.filtered)))
	}

	// Item list render
	listHeight := m.height - 6
	start, end := m.visibleRange(listHeight)

	for i := start; i < end && i < len(m.list.filtered); i++ {
		item := m.list.filtered[i]
		selected := i == m.list.cursor

		favIcon := ""
		if item.Favorite {
			favIcon = "⭐ "
		}

		line := fmt.Sprintf("%s%s %s", favIcon, item.Icon(), item.Name)
		if selected {
			b.WriteString(styleSelected.Render("▎ " + line))
		} else {
			b.WriteString(styleItem.Render(line))
		}
		b.WriteString("\n")

		// Subtitle line
		subtitle := "   "
		if u := item.Username(); u != "" {
			subtitle += u
		}
		if uri := item.PrimaryURI(); uri != "" {
			if u := item.Username(); u != "" {
				subtitle += "  •  "
			}
			subtitle += uri
		}
		if selected {
			b.WriteString(styleSelected.Render("  " + subtitle))
		} else {
			b.WriteString(styleDim.Render(subtitle))
		}
		b.WriteString("\n")
	}

	// Toast / Error notification
	if m.toast != "" && time.Since(m.toastAt) < 3*time.Second {
		b.WriteString(styleCopied.Render(" "+m.toast) + "\n")
	} else if m.err != nil && time.Since(m.errTime) < 5*time.Second {
		b.WriteString(styleRed(" "+m.err.Error()) + "\n")
	}

	// Footer bar
	footer := styleStatusBar.Render(" Tab categories  ↑↓ nav  ↵ detail  y password  u username  o open URL  l lock  q quit")
	b.WriteString(footer)

	return lipgloss.NewStyle().Width(m.width).Render(b.String())
}

func (m *tuiModel) visibleRange(height int) (int, int) {
	n := len(m.list.filtered)
	if n == 0 {
		return 0, 0
	}
	itemsPerPage := height / 2
	if itemsPerPage < 1 {
		itemsPerPage = 1
	}

	if m.list.cursor < m.list.offset {
		m.list.offset = m.list.cursor
	}
	if m.list.cursor >= m.list.offset+itemsPerPage {
		m.list.offset = m.list.cursor - itemsPerPage + 1
	}

	end := m.list.offset + itemsPerPage
	if end > n {
		end = n
	}
	return m.list.offset, end
}

func (m *tuiModel) renderDetail() string {
	if m.detail == nil {
		return ""
	}
	item := m.detail.item

	var b strings.Builder

	titleText := fmt.Sprintf(" ← Esc Back    %s %s", item.Icon(), item.Name)
	title := styleTitleBar.Render(titleText)
	b.WriteString(title + "\n\n")

	var details strings.Builder

	details.WriteString(fmt.Sprintf(" %s  %s\n",
		styleDetailLabel.Render("Type:"),
		styleDetailValue.Render(item.TypeLabel())))

	if u := item.Username(); u != "" {
		copied := ""
		if m.detail.copiedField == "email" && time.Since(m.detail.copiedAt) < 2*time.Second {
			copied = styleCopied.Render(" ✓ copied!")
		}
		details.WriteString(fmt.Sprintf(" %s  %s%s\n",
			styleDetailLabel.Render("Username:"),
			styleDetailValue.Render(u),
			copied))
	}

	if m.detail.fetching {
		details.WriteString(fmt.Sprintf(" %s  %s\n",
			styleDetailLabel.Render("Password:"),
			styleDetailValue.Render("fetching...")))
	} else if m.detail.err != "" {
		details.WriteString(fmt.Sprintf(" %s  %s\n",
			styleDetailLabel.Render("Password:"),
			styleDetailValue.Render(styleRed(m.detail.err))))
	} else if m.detail.password != "" {
		copied := ""
		if m.detail.copiedField == "password" && time.Since(m.detail.copiedAt) < 2*time.Second {
			copied = styleCopied.Render(" ✓ copied (30s auto-clear)!")
		}
		dispPass := strings.Repeat("•", 16)
		if m.detail.showPassword {
			dispPass = m.detail.password
		}
		details.WriteString(fmt.Sprintf(" %s  %s%s\n",
			styleDetailLabel.Render("Password:"),
			styleDetailValue.Render(dispPass),
			copied))
	} else {
		details.WriteString(fmt.Sprintf(" %s  %s\n",
			styleDetailLabel.Render("Password:"),
			styleDetailValue.Render("(locked)")))
	}

	if uri := item.PrimaryURI(); uri != "" {
		copied := ""
		if m.detail.copiedField == "uri" && time.Since(m.detail.copiedAt) < 2*time.Second {
			copied = styleCopied.Render(" ✓ copied!")
		}
		details.WriteString(fmt.Sprintf(" %s  %s%s\n",
			styleDetailLabel.Render("URI:"),
			styleDetailValue.Render(uri),
			copied))
	}

	if item.Notes != "" {
		copied := ""
		if m.detail.copiedField == "notes" && time.Since(m.detail.copiedAt) < 2*time.Second {
			copied = styleCopied.Render(" ✓ copied!")
		}
		details.WriteString(fmt.Sprintf(" %s  %s%s\n",
			styleDetailLabel.Render("Notes:"),
			styleDetailValue.Render(item.Notes),
			copied))
	}

	b.WriteString(styleBox.Width(min(70, m.width-4)).Render(details.String()) + "\n\n")

	b.WriteString(fmt.Sprintf(" %s %s  %s %s  %s %s  %s %s  %s %s\n\n",
		styleKey.Render("[y/p]"), "copy password",
		styleKey.Render("[u]"), "copy username",
		styleKey.Render("[v]"), "toggle visibility",
		styleKey.Render("[o]"), "open browser",
		styleKey.Render("[Esc]"), "back",
	))

	if m.detail.status != "" && time.Since(m.detail.statusAt) < 3*time.Second {
		if strings.HasPrefix(m.detail.status, "✓") {
			b.WriteString(styleCopied.Render(" "+m.detail.status) + "\n\n")
		} else {
			b.WriteString(styleRed(" "+m.detail.status) + "\n\n")
		}
	}

	footer := styleStatusBar.Render(" Esc back   q quit")
	b.WriteString(footer)

	return lipgloss.NewStyle().Width(m.width).Render(b.String())
}

func (m *tuiModel) stateIcon() string {
	switch m.state {
	case "unlocked":
		return "🔓"
	case "locked":
		return "🔒"
	case "unauthenticated":
		return "🔑"
	case "error":
		return "⚠"
	default:
		return "⋯"
	}
}

// ── Helpers ──────────────────────────────────────────────

func isPrintableKey(msg tea.KeyMsg) bool {
	s := msg.String()
	if len(s) != 1 {
		return false
	}
	r := rune(s[0])
	return r >= 32 && r <= 126
}

func styleRed(s string) string {
	return lipgloss.NewStyle().Foreground(clrRed).Render(s)
}
