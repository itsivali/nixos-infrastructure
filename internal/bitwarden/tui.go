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

// ── Styling ──────────────────────────────────────────────

var (
	clrBorder   = lipgloss.Color("#585b70")
	clrDim      = lipgloss.Color("#6c7086")
	clrAccent   = lipgloss.Color("#89b4fa")
	clrGreen    = lipgloss.Color("#a6e3a1")
	clrYellow   = lipgloss.Color("#f9e2af")
	clrRed      = lipgloss.Color("#f38ba8")
	clrWhite    = lipgloss.Color("#cdd6f4")
	clrSurface  = lipgloss.Color("#313244")
	styleHeader = lipgloss.NewStyle().
			Foreground(clrAccent).
			Bold(true).
			Padding(0, 1)

	styleItem = lipgloss.NewStyle().
			Padding(0, 2)

	styleSelected = lipgloss.NewStyle().
			Background(clrSurface).
			Padding(0, 2)

	styleDim = lipgloss.NewStyle().
			Foreground(clrDim).
			Padding(0, 2)

	styleFooter = lipgloss.NewStyle().
			Foreground(clrDim).
			Padding(0, 1)

	styleDetailLabel = lipgloss.NewStyle().
				Foreground(clrDim).
				Width(11).
				Align(lipgloss.Right)

	styleDetailValue = lipgloss.NewStyle().
				Foreground(clrWhite).
				Padding(0, 0, 0, 1)

	styleCopied = lipgloss.NewStyle().
			Foreground(clrGreen).
			Bold(true)

	styleKey = lipgloss.NewStyle().
			Foreground(clrAccent).
			Bold(true)

	styleTitleBar = lipgloss.NewStyle().
			Foreground(clrWhite).
			Background(lipgloss.Color("#45475a")).
			Padding(0, 1)

	styleStatusBar = lipgloss.NewStyle().
			Foreground(clrDim).
			Padding(0, 1)
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

// ── Model ─────────────────────────────────────────────────

type viewMode int

const (
	modeList viewMode = iota
	modeDetail
)

type listModel struct {
	items    []VaultItem
	filtered []VaultItem
	cursor   int
	offset   int
	filter   []rune
}

type detailModel struct {
	item        VaultItem
	password    string
	fetching    bool
	copiedField string
	copiedAt    time.Time
	err         string
}

type tuiModel struct {
	mode  viewMode
	state string // "loading", "unlocked", "locked", "error"

	width  int
	height int

	list   listModel
	detail *detailModel

	client  *Client
	env     *Env

	cacheFile     string
	cacheTimeFile string
	cacheTTL      time.Duration
	sessionFile   string

	initialFilter string

	err error
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
	rtDir := os.Getenv("BW_RT_DIR")
	if rtDir == "" {
		xdgRun := os.Getenv("XDG_RUNTIME_DIR")
		if xdgRun == "" {
			xdgRun = "/run/user/1000"
		}
		rtDir = xdgRun + "/bitwarden"
	}
	return &Env{
		BwPath:        FindBwPath(),
		Session:       SessionFromEnv(),
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
	return tea.Batch(m.loadItems(), m.restoreSession())
}

func (m *tuiModel) restoreSession() tea.Cmd {
	return func() tea.Msg {
		if m.env.Session != "" {
			m.client.Session = m.env.Session
			return nil
		}
		session, err := ReadSessionFromFile(m.sessionFile)
		if err != nil {
			return nil
		}
		if session != "" {
			m.client.Session = session
			m.env.Session = session
		}
		return nil
	}
}

func (m *tuiModel) loadItems() tea.Cmd {
	return func() tea.Msg {
		// Try cache first
		var items []VaultItem
		var err error

		if m.cacheFile != "" {
			items, err = ReadCache(m.cacheFile)
			if err == nil && len(items) > 0 {
				m.state = "unlocked"
				return itemsLoadedMsg{items: items}
			}
		}

		// Fall back to live listing
		items, err = m.client.ListItems()
		if err != nil {
			m.state = "error"
			return itemsErrMsg{err: err}
		}
		m.state = "unlocked"
		return itemsLoadedMsg{items: items}
	}
}

func (m *tuiModel) applyFilter() {
	filter := strings.ToLower(string(m.list.filter))
	if filter == "" {
		m.list.filtered = make([]VaultItem, len(m.list.items))
		copy(m.list.filtered, m.list.items)
	} else {
		m.list.filtered = nil
		for _, item := range m.list.items {
			if strings.Contains(strings.ToLower(item.Name), filter) ||
				strings.Contains(strings.ToLower(item.Username()), filter) {
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

func (m *tuiModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		if !m.ready() {
			m.ready()
		}

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
		return m, nil

	case itemsErrMsg:
		m.err = msg.err
		m.state = "error"
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
		return m, m.loadItems()

	case syncErrMsg:
		m.err = msg.err
		return m, nil
	}

	return m, nil
}

func (m *tuiModel) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch m.mode {
	case modeList:
		return m.handleListKey(msg)
	case modeDetail:
		return m.handleDetailKey(msg)
	}
	return m, nil
}

func (m *tuiModel) handleListKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit

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
				item: item,
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

	case "r":
		return m, m.reloadItems()

	case "s":
		return m, m.syncVault()

	default:
		if isPrintableKey(msg) {
			m.list.filter = append(m.list.filter, []rune(msg.String())...)
			m.applyFilter()
		}
	}

	return m, nil
}

func (m *tuiModel) handleDetailKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit

	case "esc", "left":
		m.mode = modeList
		m.detail = nil
		return m, nil

	case "p":
		if m.detail.password != "" {
			if err := CopyToClipboard(m.detail.password); err == nil {
				m.detail.copiedField = "password"
				m.detail.copiedAt = time.Now()
			}
		}

	case "e":
		if u := m.detail.item.Username(); u != "" {
			if err := CopyToClipboard(u); err == nil {
				m.detail.copiedField = "email"
				m.detail.copiedAt = time.Now()
			}
		}

	case "u":
		if uri := m.detail.item.PrimaryURI(); uri != "" {
			if err := CopyToClipboard(uri); err == nil {
				m.detail.copiedField = "uri"
				m.detail.copiedAt = time.Now()
			}
		}

	case "n":
		if m.detail.item.Notes != "" {
			if err := CopyToClipboard(m.detail.item.Notes); err == nil {
				m.detail.copiedField = "notes"
				m.detail.copiedAt = time.Now()
			}
		}

	case "o":
		if uri := m.detail.item.PrimaryURI(); uri != "" {
			exec.Command("xdg-open", uri).Start()
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

// ── View ──────────────────────────────────────────────────

func (m *tuiModel) View() string {
	if !m.ready() {
		return "Loading..."
	}

	switch m.mode {
	case modeList:
		return m.renderList()
	case modeDetail:
		return m.renderDetail()
	}
	return ""
}

func (m *tuiModel) renderList() string {
	var b strings.Builder

	// Title bar
	title := styleTitleBar.Render(fmt.Sprintf(" BW — Bitwarden Vault    %d items    %s",
		len(m.list.items), m.stateIcon()))
	b.WriteString(title)
	b.WriteString("\n")

	// Item list
	listHeight := m.height - 4
	start, end := m.visibleRange(listHeight)

	for i := start; i < end && i < len(m.list.filtered); i++ {
		item := m.list.filtered[i]
		selected := i == m.list.cursor

		line := fmt.Sprintf("%s %s", item.Icon(), item.Name)
		if selected {
			b.WriteString(styleSelected.Render(line))
		} else {
			b.WriteString(styleItem.Render(line))
		}
		b.WriteString("\n")

		// Subtitle line
		subtitle := ""
		if u := item.Username(); u != "" {
			subtitle = "   " + u
		}
		if selected {
			b.WriteString(styleSelected.Render(subtitle))
		} else {
			b.WriteString(styleDim.Render(subtitle))
		}
		b.WriteString("\n")
	}

	// Footer
	footerStr := m.renderFilter()
	if m.err != nil {
		footerStr += styleRed(" " + m.err.Error())
	}
	footer := styleStatusBar.Render(footerStr)
	b.WriteString(footer)

	return lipgloss.NewStyle().Width(m.width).Render(b.String())
}

func (m *tuiModel) renderFilter() string {
	filter := string(m.list.filter)
	if filter == "" {
		return " / filter…    ↑↓ navigate  ↵ select  r refresh  s sync  q quit"
	}
	return fmt.Sprintf(" / %s    %d matches", filter, len(m.list.filtered))
}

func (m *tuiModel) visibleRange(height int) (int, int) {
	n := len(m.list.filtered)
	if n == 0 {
		return 0, 0
	}
	// Each item takes 2 lines (name + subtitle)
	itemsPerPage := height / 2
	if itemsPerPage < 1 {
		itemsPerPage = 1
	}

	// Adjust offset so cursor is visible
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

	// Title bar with back button and actions
	titleText := fmt.Sprintf(" ← Back    %s %s", item.Icon(), item.Name)
	title := styleTitleBar.Render(titleText)
	b.WriteString(title)
	b.WriteString("\n")

	// Item details
	b.WriteString("\n")

	// Type
	b.WriteString(fmt.Sprintf(" %s  %s\n",
		styleDetailLabel.Render("Type:"),
		styleDetailValue.Render(item.TypeLabel())))

	// Username
	if u := item.Username(); u != "" {
		copied := ""
		if m.detail.copiedField == "email" && time.Since(m.detail.copiedAt) < 2*time.Second {
			copied = styleCopied.Render(" ✓ copied!")
		}
		b.WriteString(fmt.Sprintf(" %s  %s%s\n",
			styleDetailLabel.Render("Username:"),
			styleDetailValue.Render(u),
			copied))
	}

	// Password
	if m.detail.fetching {
		b.WriteString(fmt.Sprintf(" %s  %s\n",
			styleDetailLabel.Render("Password:"),
			styleDetailValue.Render("fetching...")))
	} else if m.detail.err != "" {
		b.WriteString(fmt.Sprintf(" %s  %s\n",
			styleDetailLabel.Render("Password:"),
			styleDetailValue.Render(styleRed(m.detail.err))))
	} else if m.detail.password != "" {
		copied := ""
		if m.detail.copiedField == "password" && time.Since(m.detail.copiedAt) < 2*time.Second {
			copied = styleCopied.Render(" ✓ copied!")
		}
		b.WriteString(fmt.Sprintf(" %s  %s%s\n",
			styleDetailLabel.Render("Password:"),
			styleDetailValue.Render(strings.Repeat("•", 16)),
			copied))
	} else {
		b.WriteString(fmt.Sprintf(" %s  %s\n",
			styleDetailLabel.Render("Password:"),
			styleDetailValue.Render("(locked)")))
	}

	// URI
	if uri := item.PrimaryURI(); uri != "" {
		copied := ""
		if m.detail.copiedField == "uri" && time.Since(m.detail.copiedAt) < 2*time.Second {
			copied = styleCopied.Render(" ✓ copied!")
		}
		b.WriteString(fmt.Sprintf(" %s  %s%s\n",
			styleDetailLabel.Render("URI:"),
			styleDetailValue.Render(uri),
			copied))
	}

	// Notes
	if item.Notes != "" {
		copied := ""
		if m.detail.copiedField == "notes" && time.Since(m.detail.copiedAt) < 2*time.Second {
			copied = styleCopied.Render(" ✓ copied!")
		}
		// Truncate notes to fit
		notes := item.Notes
		if len(notes) > 60 {
			notes = notes[:60] + "..."
		}
		b.WriteString(fmt.Sprintf(" %s  %s%s\n",
			styleDetailLabel.Render("Notes:"),
			styleDetailValue.Render(notes),
			copied))
	}

	// Separator
	b.WriteString("\n")
	b.WriteString(strings.Repeat("─", m.width-2))
	b.WriteString("\n\n")

	// Action keys
	b.WriteString(fmt.Sprintf(" %s %s  %s %s  %s %s  %s %s  %s %s\n\n",
		styleKey.Render("[p]"), "password",
		styleKey.Render("[e]"), "email",
		styleKey.Render("[u]"), "uri",
		styleKey.Render("[n]"), "notes",
		styleKey.Render("[o]"), "open browser",
	))

	// Footer
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

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}


