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
	loading      bool
	showDetail   bool

	filter    string
	filtering bool

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
	return tea.Batch(m.refreshCmd(), m.autoRefreshCmd())
}

func (m *model) autoRefreshCmd() tea.Cmd {
	return tea.Tick(30*time.Second, func(t time.Time) tea.Msg {
		return refreshTick(t)
	})
}

func (m *model) refreshCmd() tea.Cmd {
	m.loading = true
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
		if m.filtering {
			switch msg.String() {
			case "esc":
				m.filter = ""
				m.filtering = false
				m.moduleCursor = 0
				m.scrollOffset = 0
			case "enter":
				m.filtering = false
			case "backspace":
				if len(m.filter) > 0 {
					m.filter = m.filter[:len(m.filter)-1]
				}
				m.moduleCursor = 0
				m.scrollOffset = 0
			case "space":
				m.filter += " "
				m.moduleCursor = 0
				m.scrollOffset = 0
			default:
				if len(msg.String()) == 1 {
					m.filter += msg.String()
					m.moduleCursor = 0
					m.scrollOffset = 0
				}
			}
			break
		}
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "r":
			return m, m.refreshCmd()
		case "?":
			m.helpVisible = !m.helpVisible
		case "/":
			if m.activeTab == 1 && !m.showDetail {
				m.filtering = true
				m.filter = ""
			}
		case "tab":
			m.activeTab = (m.activeTab + 1) % len(m.tabs)
			m.moduleCursor = 0
			m.scrollOffset = 0
			m.showDetail = false
			m.filter = ""
			m.filtering = false
		case "shift+tab":
			m.activeTab = (m.activeTab - 1 + len(m.tabs)) % len(m.tabs)
			m.moduleCursor = 0
			m.scrollOffset = 0
			m.showDetail = false
			m.filter = ""
			m.filtering = false
		case "enter":
			if m.activeTab == 1 && len(m.filteredModules()) > 0 {
				m.showDetail = !m.showDetail
			}
		case "esc":
			m.showDetail = false
			if m.filter != "" {
				m.filter = ""
				m.moduleCursor = 0
				m.scrollOffset = 0
			}
		case "up", "k":
			if m.showDetail {
				break
			}
			if m.activeTab == 1 {
				flen := len(m.filteredModules())
				if m.moduleCursor > 0 {
					m.moduleCursor--
				}
				if m.scrollOffset > 0 {
					m.scrollOffset--
				}
				// Clamp cursor to filtered list
				if m.moduleCursor >= flen && flen > 0 {
					m.moduleCursor = flen - 1
				}
			}
		case "down", "j":
			if m.showDetail {
				break
			}
			if m.activeTab == 1 {
				flen := len(m.filteredModules())
				if m.moduleCursor < flen-1 {
					m.moduleCursor++
				}
				m.scrollOffset++
				// Clamp cursor to filtered list
				if m.moduleCursor >= flen && flen > 0 {
					m.moduleCursor = flen - 1
				}
			}
		}

	case errMsg:
		m.err = error(msg)

	case refreshDone:
		m.lastRefresh = time.Time(msg)
		m.loading = false

	case refreshTick:
		return m, m.refreshCmd()
	}

	return m, nil
}

func (m *model) View() string {
	if !m.ready {
		return m.term.Dim("  Loading...")
	}

	var b strings.Builder

	b.WriteString(m.renderHeader())
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

func (m *model) tabCounts() []int {
	if m.repo.Result == nil {
		return []int{0, 0, 0, 0}
	}
	dups := len(m.repo.CheckDuplicateImports())
	orphans := len(m.repo.CheckOrphanModules())
	missing := len(m.repo.CheckMissingDocHeaders())
	healthBad := dups + orphans + missing
	_, _, total := m.repo.ModuleCount()
	return []int{
		total,
		len(m.modules),
		healthBad,
		len(m.repo.Result.Domains),
	}
}

func (m *model) renderTabs() string {
	var b strings.Builder
	counts := m.tabCounts()
	for i, tab := range m.tabs {
		label := tab
		if i < len(counts) && counts[i] > 0 {
			label = fmt.Sprintf("%s [%d]", tab, counts[i])
		}
		if i == m.activeTab {
			b.WriteString(m.term.Good(" ◆ " + label + " "))
		} else {
			b.WriteString(m.term.Dim("   " + label + "  "))
		}
	}
	if m.loading {
		b.WriteString("  " + spinner())
	}
	b.WriteString("\n")
	return b.String()
}

var spinIdx int
var spinFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

func spinner() string {
	spinIdx = (spinIdx + 1) % len(spinFrames)
	return spinFrames[spinIdx]
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

func (m *model) filteredModules() []scanner.Module {
	if m.filter == "" {
		return m.modules
	}
	lower := strings.ToLower(m.filter)
	var result []scanner.Module
	for _, mod := range m.modules {
		if strings.Contains(strings.ToLower(mod.RelPath), lower) {
			result = append(result, mod)
		}
	}
	return result
}

func (m *model) renderModules() string {
	filtered := m.filteredModules()
	if len(m.modules) == 0 {
		return "  " + m.term.Dim("No modules found.")
	}

	var b strings.Builder

	subtitle := fmt.Sprintf("All Modules (%d)", len(m.modules))
	if m.filter != "" {
		subtitle = fmt.Sprintf("All Modules (%d/%d filtered)", len(filtered), len(m.modules))
	}
	b.WriteString(m.term.Subsection(subtitle) + "\n\n")

	if m.filtering {
		b.WriteString(m.term.Dim("  Filter: ") + m.term.Bold(m.filter+"▎") + "\n\n")
	}

	if len(filtered) == 0 {
		b.WriteString("  " + m.term.Warn("No modules match filter: "+m.filter) + "\n")
		return b.String()
	}

	if m.showDetail && m.moduleCursor < len(filtered) {
		b.WriteString(m.renderModuleDetail(filtered[m.moduleCursor]))
		return b.String()
	}

	contentHeight := m.height - 10
	start := m.scrollOffset
	end := start + contentHeight
	if end > len(filtered) {
		end = len(filtered)
	}

	for i, mod := range filtered[start:end] {
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

func (m *model) renderModuleDetail(mod scanner.Module) string {
	var b strings.Builder
	b.WriteString(m.term.Subsection(mod.RelPath) + "\n\n")
	b.WriteString(m.term.KeyValue("Category", string(mod.Category)) + "\n")
	b.WriteString(m.term.KeyValue("Type", m.term.Bold(string(mod.Type))) + "\n")
	b.WriteString(m.term.KeyValue("Domain", m.term.Dim(mod.Domain)) + "\n")
	if mod.FileCount > 0 {
		b.WriteString(m.term.KeyValue("Files", fmt.Sprintf("%d", mod.FileCount)) + "\n")
	}
	if mod.LineCount > 0 {
		b.WriteString(m.term.KeyValue("Lines", fmt.Sprintf("%d", mod.LineCount)) + "\n")
	}

	if info, ok := m.repo.Parsed[mod.Path]; ok {
		if info.Purpose != "" {
			b.WriteString("\n" + m.term.Subsection("Purpose") + "\n")
			words := strings.Fields(info.Purpose)
			var wrapped string
			for i, w := range words {
				if i > 0 && i%12 == 0 {
					wrapped += "\n  "
				} else if i > 0 {
					wrapped += " "
				}
				wrapped += w
			}
			b.WriteString("  " + wrapped + "\n")
		}
		if len(info.Owns) > 0 {
			b.WriteString("\n" + m.term.Subsection("Ownership") + "\n")
			for _, o := range info.Owns {
				b.WriteString(m.term.Dim("  " + o) + "\n")
			}
		}
		if len(info.Imports) > 0 {
			b.WriteString("\n" + m.term.Subsection("Imports") + "\n")
			maxShow := min(len(info.Imports), 10)
			for _, imp := range info.Imports[:maxShow] {
				b.WriteString(m.term.Dim("  " + imp) + "\n")
			}
			if len(info.Imports) > maxShow {
				b.WriteString(m.term.Dim(fmt.Sprintf("  … +%d more\n", len(info.Imports)-maxShow)))
			}
		}
		if info.HasOptions {
			b.WriteString("\n" + m.term.Subsection("Options") + "\n")
			b.WriteString("  " + m.term.Good("Declares options") + "\n")
		}
	} else {
		b.WriteString("\n" + m.term.Dim("  No parsed metadata available.") + "\n")
	}
	b.WriteString("\n" + m.term.Dim("  [Esc] back  [Enter] toggle detail"))
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
	help := m.term.Dim("  ? help  ↑↓ scroll  / filter  enter detail  tab switch  r refresh  q quit")
	if m.helpVisible {
		help += "\n" + m.term.Dim("  IVALI Dashboard — Bubbletea TUI for repository management")
		help += "\n" + m.term.Dim("  Tab/S-Tab: Switch panels  Up/Down: Navigate lists")
		help += "\n" + m.term.Dim("  /: Filter modules  Esc: Clear filter  Backspace: Delete char")
		help += "\n" + m.term.Dim("  Enter: Toggle module detail  Esc: Back to list")
		help += "\n" + m.term.Dim("  r: Refresh data  q/Ctrl+C: Quit")
	}
	return help
}

type errMsg error
type refreshDone time.Time
type refreshTick time.Time
