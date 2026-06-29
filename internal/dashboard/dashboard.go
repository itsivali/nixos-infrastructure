package dashboard

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/charmbracelet/bubbletea"
	"github.com/willisivali/nixos-infrastructure/internal/repository"
	"github.com/willisivali/nixos-infrastructure/internal/scanner"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

type model struct {
	repo   *repository.Repository
	term   *terminal.Terminal
	ready  bool
	err    error

	tabs       []string
	activeTab  int
	width      int
	height     int

	moduleCursor int
	scrollOffset int
	helpVisible  bool
	lastRefresh  time.Time

	modules []scanner.Module
}

func New(repo *repository.Repository, term *terminal.Terminal) tea.Model {
	return &model{
		repo:  repo,
		term:  term,
		tabs:  []string{"Overview", "Modules", "Health", "Domains"},
	}
}

func (m *model) Init() tea.Cmd {
	return m.refreshCmd()
}

func (m *model) refreshCmd() tea.Cmd {
	return func() tea.Msg {
		if err := m.repo.EnsureScanned(); err != nil {
			return errMsg(err)
		}
		m.modules = m.repo.Result.AllModules
		return refreshDone(time.Now())
	}
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.ready = true

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "r":
			return m, m.refreshCmd()
		case "?":
			m.helpVisible = !m.helpVisible
		case "tab":
			m.activeTab = (m.activeTab + 1) % len(m.tabs)
			m.moduleCursor = 0
			m.scrollOffset = 0
		case "shift+tab":
			m.activeTab = (m.activeTab - 1 + len(m.tabs)) % len(m.tabs)
			m.moduleCursor = 0
			m.scrollOffset = 0
		case "up", "k":
			if m.activeTab == 1 && m.moduleCursor > 0 {
				m.moduleCursor--
			}
			if m.scrollOffset > 0 {
				m.scrollOffset--
			}
		case "down", "j":
			if m.activeTab == 1 && m.moduleCursor < len(m.modules)-1 {
				m.moduleCursor++
			}
			m.scrollOffset++
		}

	case errMsg:
		m.err = error(msg)

	case refreshDone:
		m.lastRefresh = time.Time(msg)
	}

	return m, nil
}

func (m *model) View() string {
	if !m.ready {
		return m.term.Dim("  Loading...")
	}

	var b strings.Builder

	b.WriteString(m.renderHeader())
	b.WriteString("\n")
	b.WriteString(m.renderTabs())
	b.WriteString("\n\n")

	switch m.activeTab {
	case 0:
		b.WriteString(m.renderOverview())
	case 1:
		b.WriteString(m.renderModules())
	case 2:
		b.WriteString(m.renderHealth())
	case 3:
		b.WriteString(m.renderDomains())
	}

	b.WriteString("\n")
	b.WriteString(m.renderHelpBar())

	return b.String()
}

func (m *model) renderHeader() string {
	return m.term.H1("IVALI Dashboard")
}

func (m *model) renderTabs() string {
	var b strings.Builder
	for i, tab := range m.tabs {
		if i == m.activeTab {
			b.WriteString(m.term.Good(" ◆ " + tab + " "))
		} else {
			b.WriteString(m.term.Dim("   " + tab + "  "))
		}
	}
	return b.String()
}

func (m *model) renderOverview() string {
	if m.repo.Result == nil {
		return "  " + m.term.Dim("No data — run ivali scan first.")
	}

	r := m.repo
	nixos, hm, total := r.ModuleCount()
	dups := len(r.CheckDuplicateImports())
	orphans := len(r.CheckOrphanModules())
	domains := r.DomainList()
	hosts := r.HostList()
	inputs := r.FlakeInputs()

	var b strings.Builder

	b.WriteString(m.term.Subsection("Repository") + "\n")
	b.WriteString(m.term.KeyValue("Hosts", fmt.Sprintf("%d", len(hosts))) + "\n")
	b.WriteString(m.term.KeyValue("NixOS modules", fmt.Sprintf("%d", nixos)) + "\n")
	b.WriteString(m.term.KeyValue("Home Manager", fmt.Sprintf("%d", hm)) + "\n")
	b.WriteString(m.term.KeyValue("Total modules", fmt.Sprintf("%d", total)) + "\n")
	b.WriteString(m.term.KeyValue("Domains", fmt.Sprintf("%d", len(domains))) + "\n")
	b.WriteString(m.term.KeyValue("Flake inputs", fmt.Sprintf("%d", inputs)) + "\n")
	b.WriteString(m.term.KeyValue("Total files", fmt.Sprintf("%d", r.FileCount())) + "\n")
	b.WriteString(m.term.KeyValue("Last scan", r.ScanTime.Format("15:04:05")) + "\n")

	b.WriteString("\n")
	b.WriteString(m.term.Subsection("Health") + "\n")
	if dups > 0 {
		b.WriteString(m.term.KeyValue("Duplicate imports", m.term.Warn(fmt.Sprintf("%d", dups))) + "\n")
	} else {
		b.WriteString(m.term.KeyValue("Duplicate imports", m.term.Good("none")) + "\n")
	}
	if orphans > 0 {
		b.WriteString(m.term.KeyValue("Orphan modules", m.term.Warn(fmt.Sprintf("%d", orphans))) + "\n")
	} else {
		b.WriteString(m.term.KeyValue("Orphan modules", m.term.Good("none")) + "\n")
	}

	return b.String()
}

func (m *model) renderModules() string {
	if len(m.modules) == 0 {
		return "  " + m.term.Dim("No modules found.")
	}

	var b strings.Builder

	b.WriteString(m.term.Subsection(fmt.Sprintf("All Modules (%d)", len(m.modules))) + "\n\n")

	contentHeight := m.height - 10
	start := m.scrollOffset
	end := start + contentHeight
	if end > len(m.modules) {
		end = len(m.modules)
	}

	for i, mod := range m.modules[start:end] {
		idx := start + i
		cursor := "  "
		if idx == m.moduleCursor {
			cursor = m.term.Good("▸ ")
		}

		cat := string(mod.Category)
		line := fmt.Sprintf("%s%s  %s", cursor, m.term.Dim(cat), mod.RelPath)
		b.WriteString(line + "\n")
	}

	return b.String()
}

func (m *model) renderHealth() string {
	if m.repo.Result == nil {
		return "  " + m.term.Dim("No data — run ivali scan first.")
	}

	r := m.repo
	dups := r.CheckDuplicateImports()
	orphans := r.CheckOrphanModules()
	missing := r.CheckMissingDocHeaders()
	nixos, hm, total := r.ModuleCount()

	var b strings.Builder

	b.WriteString(m.term.Subsection("Module Integrity") + "\n")
	b.WriteString(fmt.Sprintf("  %s  Modules: %d NixOS + %d HM = %d\n\n",
		m.term.Good("✓"), nixos, hm, total))

	b.WriteString(m.term.Subsection("Duplicate Imports") + "\n")
	if len(dups) == 0 {
		b.WriteString(fmt.Sprintf("  %s  No duplicates\n", m.term.Good("✓")))
	} else {
		count := min(len(dups), 8)
		for _, d := range dups[:count] {
			short := d
			if len(short) > 50 {
				short = short[:50] + "…"
			}
			b.WriteString(fmt.Sprintf("  %s  %s\n", m.term.Bad("✗"), m.term.Dim(short)))
		}
		if len(dups) > count {
			b.WriteString(fmt.Sprintf("  %s  (+ %d more)\n", m.term.Dim("⋯"), len(dups)-count))
		}
	}
	b.WriteString("\n")

	b.WriteString(m.term.Subsection("Orphan Modules") + "\n")
	if len(orphans) == 0 {
		b.WriteString(fmt.Sprintf("  %s  None\n", m.term.Good("✓")))
	} else {
		for _, o := range orphans {
			b.WriteString(fmt.Sprintf("  %s  %s\n", m.term.Warn("⚠"), m.term.Dim(o)))
		}
	}
	b.WriteString("\n")

	b.WriteString(m.term.Subsection("Documentation") + "\n")
	if len(missing) == 0 {
		b.WriteString(fmt.Sprintf("  %s  All documented\n", m.term.Good("✓")))
	} else {
		count := min(len(missing), 6)
		for _, d := range missing[:count] {
			b.WriteString(fmt.Sprintf("  %s  %s\n", m.term.Warn("⚠"), m.term.Dim(d)))
		}
		if len(missing) > count {
			b.WriteString(fmt.Sprintf("  %s  (+ %d more)\n", m.term.Dim("⋯"), len(missing)-count))
		}
	}

	return b.String()
}

func (m *model) renderDomains() string {
	if m.repo.Result == nil || len(m.repo.Result.Domains) == 0 {
		return "  " + m.term.Dim("No domains found.")
	}

	var b strings.Builder

	type domainInfo struct {
		Name        string
		Path        string
		Category    string
		FileCount   int
		ModuleCount int
	}
	domains := make([]domainInfo, 0)
	for _, d := range m.repo.Result.Domains {
		domains = append(domains, domainInfo{
			Name:        d.Name,
			Path:        d.RelPath,
			Category:    string(d.Category),
			FileCount:   d.FileCount,
			ModuleCount: len(d.Modules),
		})
	}
	sort.Slice(domains, func(i, j int) bool {
		return domains[i].Name < domains[j].Name
	})

	b.WriteString(m.term.Subsection(fmt.Sprintf("Domains (%d)", len(domains))) + "\n\n")

	for _, d := range domains {
		b.WriteString(fmt.Sprintf("  %s  %s  %s  (%d files, %d modules)\n",
			m.term.Good("▸"),
			m.term.Bold(d.Name),
			m.term.Dim(d.Category),
			d.FileCount,
			d.ModuleCount))
	}

	return b.String()
}

func (m *model) renderHelpBar() string {
	help := m.term.Dim("  ? help  ↑↓ scroll  tab switch  r refresh  q quit")
	if m.helpVisible {
		help += "\n" + m.term.Dim("  IVALI Dashboard — Bubbletea TUI for repository management")
		help += "\n" + m.term.Dim("  Tab/S-Tab: Switch panels  Up/Down: Navigate lists")
		help += "\n" + m.term.Dim("  r: Refresh data  q/Ctrl+C: Quit")
	}
	return help
}

type errMsg error
type refreshDone time.Time
