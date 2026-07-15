package dashboard

import (
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/willisivali/nixos-infrastructure/internal/repository"
	"github.com/willisivali/nixos-infrastructure/internal/scanner"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

type sortField int

const (
	sortNone sortField = iota
	sortCategory
	sortType
	sortName
	sortLines
)

type model struct {
	repo   *repository.Repository
	term   *terminal.Terminal
	ready  bool
	err    error

	tabs         []string
	tabIcons     []string
	activeTab    int
	width        int
	height       int

	moduleCursor int
	scrollOffset int
	helpVisible  bool
	lastRefresh  time.Time
	loading      bool
	showDetail   bool

	filter    string
	filtering bool

	sortField sortField
	sortAsc   bool

	actionMode  bool
	actionCursor int
	lastAction  string
	actionResult string

	genCursor    int
	genScrollOff int
	generations  []genEntry
	genConfirm   bool

	modules []scanner.Module
}

func New(repo *repository.Repository, term *terminal.Terminal) tea.Model {
	return &model{
		repo:     repo,
		term:     term,
		tabs:     []string{"Overview", "Modules", "Health", "Domains", "Git Log", "Generations"},
		tabIcons: []string{"", "", "", "", "", ""},
	}
}

func (m *model) Init() tea.Cmd {
	return tea.Batch(m.refreshCmd(), m.autoRefreshCmd(), m.spinnerCmd())
}

func (m *model) autoRefreshCmd() tea.Cmd {
	return tea.Tick(30*time.Second, func(t time.Time) tea.Msg {
		return refreshTick(t)
	})
}

func (m *model) spinnerCmd() tea.Cmd {
	return tea.Tick(150*time.Millisecond, func(t time.Time) tea.Msg {
		return spinnerTick(t)
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
		case "a":
			if !m.filtering && !m.showDetail {
				m.actionMode = !m.actionMode
				m.actionCursor = 0
			}
		case "d":
			if m.actionMode {
				m.lastAction = "rebuild"
				m.actionResult = "Rebuilding system..."
				m.actionMode = false
				return m, tea.ExecProcess(exec.Command("sudo", "nixos-rebuild", "switch", "--flake", m.repo.Root+"#prague"), func(err error) tea.Msg {
					if err != nil {
						return actionResultMsg{action: "rebuild", err: err}
					}
					return actionResultMsg{action: "rebuild", err: nil}
				})
			}
		case "x":
			if m.actionMode {
				m.lastAction = "doctor"
				m.actionResult = "Running ivali doctor --fix..."
				m.actionMode = false
				return m, tea.ExecProcess(exec.Command("ivali", "doctor", "--fix"), func(err error) tea.Msg {
					if err != nil {
						return actionResultMsg{action: "doctor", err: err}
					}
					return actionResultMsg{action: "doctor", err: nil}
				})
			}
		case "/":
			if m.activeTab == 1 && !m.showDetail {
				m.filtering = true
				m.filter = ""
			}
		case "s":
			if m.activeTab == 1 {
				m.cycleSort()
			}
		case "tab", "l":
			m.activeTab = (m.activeTab + 1) % len(m.tabs)
			m.moduleCursor = 0
			m.scrollOffset = 0
			m.showDetail = false
			m.filter = ""
			m.filtering = false
		case "shift+tab", "h":
			m.activeTab = (m.activeTab - 1 + len(m.tabs)) % len(m.tabs)
			m.moduleCursor = 0
			m.scrollOffset = 0
			m.showDetail = false
			m.filter = ""
			m.filtering = false
		case "enter":
			if m.activeTab == 1 && len(m.filteredModules()) > 0 {
				m.showDetail = !m.showDetail
			} else if m.activeTab == 5 && len(m.generations) > 0 {
				if m.genConfirm {
					gen := m.generations[m.genCursor]
					m.genConfirm = false
					m.lastAction = "rollback"
					m.actionResult = fmt.Sprintf("Rolling back to generation %d...", gen.Number)
					profilePath := fmt.Sprintf("/nix/var/nix/profiles/system-%d-link", gen.Number)
					return m, tea.ExecProcess(exec.Command("sudo", "nixos-rebuild", "switch", "--flake", m.repo.Root+"#prague", "--profile", profilePath), func(err error) tea.Msg {
						if err != nil {
							return actionResultMsg{action: fmt.Sprintf("rollback to gen %d", gen.Number), err: err}
						}
						return actionResultMsg{action: fmt.Sprintf("rollback to gen %d", gen.Number), err: nil}
					})
				} else {
					m.genConfirm = true
				}
			}
		case "esc":
			m.showDetail = false
			m.genConfirm = false
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
				if m.moduleCursor >= flen && flen > 0 {
					m.moduleCursor = flen - 1
				}
			} else if m.activeTab == 5 && !m.genConfirm {
				if m.genCursor > 0 {
					m.genCursor--
				}
				if m.genScrollOff > 0 {
					m.genScrollOff--
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
					contentHeight := m.height - 12
					if contentHeight < 3 {
						contentHeight = 3
					}
					if m.moduleCursor >= m.scrollOffset+contentHeight {
						m.scrollOffset = m.moduleCursor - contentHeight + 1
					}
				}
			} else if m.activeTab == 5 && !m.genConfirm {
				if m.genCursor < len(m.generations)-1 {
					m.genCursor++
					contentHeight := m.height - 10
					if contentHeight < 3 {
						contentHeight = 3
					}
					if m.genCursor >= m.genScrollOff+contentHeight {
						m.genScrollOff = m.genCursor - contentHeight + 1
					}
				}
			}
		case "g":
			if m.activeTab == 1 {
				m.moduleCursor = 0
				m.scrollOffset = 0
			}
		case "G":
			if m.activeTab == 1 {
				flen := len(m.filteredModules())
				if flen > 0 {
					m.moduleCursor = flen - 1
					m.scrollOffset = flen - (m.height - 10)
					if m.scrollOffset < 0 {
						m.scrollOffset = 0
					}
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

	case spinnerTick:
		return m, m.spinnerCmd()

	case actionResultMsg:
		if msg.err != nil {
			m.actionResult = fmt.Sprintf("  ✗ %s failed: %s", msg.action, msg.err.Error())
		} else {
			m.actionResult = fmt.Sprintf("  ✓ %s completed successfully", msg.action)
		}
		return m, tea.Tick(5*time.Second, func(t time.Time) tea.Msg {
			m.actionResult = ""
			return nil
		})
	}

	return m, nil
}

func (m *model) cycleSort() {
	fields := []sortField{sortNone, sortCategory, sortType, sortName, sortLines}
	for i, f := range fields {
		if f == m.sortField {
			next := (i + 1) % len(fields)
			if next == 0 {
				m.sortField = sortNone
				m.sortAsc = true
			} else if next == i+1 {
				m.sortField = fields[next]
				m.sortAsc = true
			}
			return
		}
	}
	m.sortField = sortName
	m.sortAsc = true
}

func (m *model) sortedModules(mods []scanner.Module) []scanner.Module {
	if m.sortField == sortNone {
		return mods
	}
	sorted := make([]scanner.Module, len(mods))
	copy(sorted, mods)
	sort.Slice(sorted, func(i, j int) bool {
		var less bool
		switch m.sortField {
		case sortCategory:
			less = sorted[i].Category < sorted[j].Category
		case sortType:
			less = sorted[i].Type < sorted[j].Type
		case sortName:
			less = sorted[i].RelPath < sorted[j].RelPath
		case sortLines:
			less = sorted[i].LineCount < sorted[j].LineCount
		default:
			less = sorted[i].RelPath < sorted[j].RelPath
		}
		if !m.sortAsc {
			return !less
		}
		return less
	})
	return sorted
}

func (m *model) View() string {
	if !m.ready {
		return m.term.Dim("  Loading...")
	}

	var b strings.Builder

	b.WriteString(m.renderHeader())
	b.WriteString("\n")
	b.WriteString(m.renderTabs())
	b.WriteString("\n")

	switch m.activeTab {
	case 0:
		b.WriteString(m.renderOverview())
	case 1:
		b.WriteString(m.renderModules())
	case 2:
		b.WriteString(m.renderHealth())
	case 3:
		b.WriteString(m.renderDomains())
	case 4:
		b.WriteString(m.renderGitLog())
	case 5:
		b.WriteString(m.renderGenerations())
	}

	b.WriteString("\n")
	b.WriteString(m.renderHelpBar())

	if m.actionMode {
		b.WriteString("\n")
		b.WriteString(m.renderActionMode())
	}

	if m.actionResult != "" {
		b.WriteString("\n")
		b.WriteString("  " + m.term.Bold(m.actionResult) + "\n")
	}

	return b.String()
}

func (m *model) renderHeader() string {
	w := min(m.width-2, 74)
	line := strings.Repeat("━", w)
	return fmt.Sprintf("  %s\n  %s\n  %s",
		m.term.ColoredIcon("", m.term.Color.Purple)+m.term.ColoredIcon("  IVALI Control Plane  ", m.term.Color.Purple)+m.term.ColoredIcon("", m.term.Color.Purple),
		m.term.Dim("  NixOS Infrastructure Dashboard"),
		m.term.Dim(line))
}

func (m *model) tabCounts() []int {
	if m.repo.Result == nil {
		return []int{0, 0, 0, 0, 0, 0}
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
		-1, // Git Log — no count
		-1, // Generations — no count
	}
}

func (m *model) renderTabs() string {
	var b strings.Builder
	counts := m.tabCounts()
	for i := range m.tabs {
		icon := m.tabIcons[i]
		label := fmt.Sprintf(" %s  %s ", icon, m.tabs[i])
		if i < len(counts) && counts[i] > 0 {
			if i == 2 {
				// Health tab: green when 0 issues, red when >0
				if counts[i] == 0 {
					label = fmt.Sprintf(" %s  %s  ", icon, m.tabs[i])
					label += m.term.ColoredIcon("✓", m.term.Color.Green)
				} else {
					label = fmt.Sprintf(" %s  %s  ", icon, m.tabs[i])
					label += m.term.ColoredIcon(fmt.Sprintf(" %d ", counts[i]), m.term.Color.Red)
				}
			} else {
				label = fmt.Sprintf(" %s  %s  %d ", icon, m.tabs[i], counts[i])
			}
		}
		if i == m.activeTab {
			b.WriteString("  ")
			b.WriteString(m.term.TagBg(label, m.term.Color.White, m.term.Color.Purple))
			b.WriteString("  ")
		} else {
			b.WriteString("  ")
			b.WriteString(m.term.Dim(label))
			b.WriteString("  ")
		}
	}
	if m.loading {
		b.WriteString("  " + m.term.ColoredIcon(terminal.AnimatedSpinner(m.lastRefresh), m.term.Color.Cyan))
	}
	now := time.Now()
	elapsed := now.Sub(m.lastRefresh)
	mins := int(elapsed.Minutes())
	secs := int(elapsed.Seconds()) % 60
	if m.lastRefresh.IsZero() {
		b.WriteString(m.term.Dim(fmt.Sprintf("   --:--")))
	} else {
		b.WriteString(m.term.Dim(fmt.Sprintf("   %dm%ds ago", mins, secs)))
	}
	b.WriteString("\n")

	w := min(m.width-2, 80)
	sep := strings.Repeat("─", w)
	b.WriteString("  " + m.term.Dim(sep) + "\n")
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
	missing := len(r.CheckMissingDocHeaders())
	domains := r.DomainList()
	hosts := r.HostList()
	inputs := r.FlakeInputs()

	var b strings.Builder
	w := min(m.width-4, 70)

	// Health bar at the top
	good := total - dups - orphans - missing
	if good < 0 {
		good = 0
	}
	b.WriteString("  " + m.term.IconH1("", "Repository Health") + "\n")
	b.WriteString(m.term.HealthBar(good, missing, dups+orphans) + "\n\n")

	// Stats in a 2-column grid
	b.WriteString("  " + m.term.IconH1("", "Repository Stats") + "\n")

	stats := []struct {
		icon  string
		label string
		value string
		color lipgloss.TerminalColor
	}{
		{"", "Hosts", fmt.Sprintf("%d", len(hosts)), m.term.Color.Blue},
		{"", "NixOS modules", fmt.Sprintf("%d", nixos), m.term.Color.Purple},
		{"", "Home Manager", fmt.Sprintf("%d", hm), m.term.Color.Cyan},
		{"", "Total modules", fmt.Sprintf("%d", total), m.term.Color.White},
		{"", "Domains", fmt.Sprintf("%d", len(domains)), m.term.Color.Green},
		{"", "Flake inputs", fmt.Sprintf("%d", inputs), m.term.Color.Yellow},
		{"", "Total files", fmt.Sprintf("%d", r.FileCount()), m.term.Color.Gray},
		{"", "Last scan", r.ScanTime.Format("15:04:05"), m.term.Color.Gray},
	}

	col2 := (len(stats) + 1) / 2
	for i := 0; i < col2; i++ {
		left := stats[i]
		line := fmt.Sprintf("  %s %s: %s",
			m.term.ColoredIcon(left.icon, left.color),
			m.term.Dim(left.label),
			m.term.Bold(left.value))
		if i+col2 < len(stats) {
			right := stats[i+col2]
			pad := w - utf8Count(line)
			if pad < 2 {
				pad = 2
			}
			line += strings.Repeat(" ", pad)
			line += fmt.Sprintf("%s %s: %s",
				m.term.ColoredIcon(right.icon, right.color),
				m.term.Dim(right.label),
				m.term.Bold(right.value))
		}
		b.WriteString(line + "\n")
	}

	b.WriteString("\n")
	b.WriteString("  " + m.term.IconH1("", "Issues") + "\n")
	if dups+orphans+missing == 0 {
		b.WriteString("  " + m.term.Good("No issues found") + "\n")
	} else {
		if dups > 0 {
			b.WriteString(fmt.Sprintf("  %s %d duplicate imports\n", m.term.ColoredIcon("", m.term.Color.Red), dups))
		}
		if orphans > 0 {
			b.WriteString(fmt.Sprintf("  %s %d orphan modules\n", m.term.ColoredIcon("", m.term.Color.Yellow), orphans))
		}
		if missing > 0 {
			b.WriteString(fmt.Sprintf("  %s %d missing doc headers\n", m.term.ColoredIcon("", m.term.Color.Yellow), missing))
		}
	}

	// System info
	b.WriteString("\n")
	b.WriteString("  " + m.term.IconH1("", "System") + "\n")
	sys := getSystemInfo()
	sysItems := []struct {
		icon  string
		label string
		value string
		color lipgloss.TerminalColor
	}{
		{"", "Host", sys.hostname, m.term.Color.Blue},
		{"", "Kernel", sys.kernel, m.term.Color.Purple},
		{"", "Uptime", sys.uptime, m.term.Color.Cyan},
		{"", "Load", sys.loadAvg, m.term.Color.Yellow},
	}
	for i, item := range sysItems {
		line := fmt.Sprintf("  %s %s: %s",
			m.term.ColoredIcon(item.icon, item.color),
			m.term.Dim(item.label),
			m.term.Bold(item.value))
		if i%2 == 0 && i+1 < len(sysItems) {
			next := sysItems[i+1]
			pad := w - utf8Count(line)
			if pad < 2 {
				pad = 2
			}
			line += strings.Repeat(" ", pad)
			line += fmt.Sprintf("%s %s: %s",
				m.term.ColoredIcon(next.icon, next.color),
				m.term.Dim(next.label),
				m.term.Bold(next.value))
		}
		b.WriteString(line + "\n")
	}

	return b.String()
}

type sysInfo struct {
	hostname string
	kernel   string
	uptime   string
	loadAvg  string
}

func getSystemInfo() sysInfo {
	info := sysInfo{hostname: "unknown", kernel: "unknown", uptime: "unknown", loadAvg: "unknown"}

	host, err := os.Hostname()
	if err == nil {
		info.hostname = host
	}

	if k, err := exec.Command("uname", "-r").Output(); err == nil {
		info.kernel = strings.TrimSpace(string(k))
	}

	if u, err := os.ReadFile("/proc/uptime"); err == nil {
		parts := strings.Fields(string(u))
		if len(parts) > 0 {
			if secs, err := strconv.ParseFloat(parts[0], 64); err == nil {
				d := int(secs) / 86400
				h := int(secs) % 86400 / 3600
				m := int(secs) % 3600 / 60
				if d > 0 {
					info.uptime = fmt.Sprintf("%dd %dh %dm", d, h, m)
				} else if h > 0 {
					info.uptime = fmt.Sprintf("%dh %dm", h, m)
				} else {
					info.uptime = fmt.Sprintf("%dm", m)
				}
			}
		}
	}

	if l, err := os.ReadFile("/proc/loadavg"); err == nil {
		parts := strings.Fields(string(l))
		if len(parts) >= 3 {
			info.loadAvg = fmt.Sprintf("%s %s %s", parts[0], parts[1], parts[2])
		}
	}

	return info
}

func utf8Count(s string) int {
	count := 0
	for _, r := range s {
		if r > 127 {
			count += 2
		} else {
			count++
		}
	}
	return count
}

func (m *model) filteredModules() []scanner.Module {
	if m.filter == "" {
		return m.sortedModules(m.modules)
	}
	lower := strings.ToLower(m.filter)
	var result []scanner.Module
	for _, mod := range m.modules {
		if strings.Contains(strings.ToLower(mod.RelPath), lower) ||
			strings.Contains(strings.ToLower(string(mod.Category)), lower) ||
			strings.Contains(strings.ToLower(string(mod.Type)), lower) {
			result = append(result, mod)
		}
	}
	return m.sortedModules(result)
}

func (m *model) renderModules() string {
	filtered := m.filteredModules()
	if len(m.modules) == 0 {
		return "  " + m.term.Dim("No modules found.")
	}

	var b strings.Builder

	subtitle := fmt.Sprintf("%s All Modules (%d)", m.term.ColoredIcon("", m.term.Color.Cyan), len(m.modules))
	if m.filter != "" {
		subtitle = fmt.Sprintf("%s All Modules (%d/%d filtered)", m.term.ColoredIcon("", m.term.Color.Cyan), len(filtered), len(m.modules))
	}
	b.WriteString(m.term.Subsection(subtitle) + "\n")

	sortHint := ""
	switch m.sortField {
	case sortCategory:
		sortHint = " sorted by category"
		if m.sortAsc {
			sortHint += " "
		} else {
			sortHint += " "
		}
	case sortType:
		sortHint = " sorted by type"
		if m.sortAsc {
			sortHint += " "
		} else {
			sortHint += " "
		}
	case sortName:
		sortHint = " sorted by name"
		if m.sortAsc {
			sortHint += " "
		} else {
			sortHint += " "
		}
	case sortLines:
		sortHint = " sorted by lines"
		if m.sortAsc {
			sortHint += " "
		} else {
			sortHint += " "
		}
	}
	if sortHint != "" {
		b.WriteString("  " + m.term.Dim(sortHint) + "\n")
	}
	b.WriteString("\n")

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

	contentHeight := m.height - 12
	if contentHeight < 3 {
		contentHeight = 3
	}
	start := m.scrollOffset
	end := start + contentHeight
	if end > len(filtered) {
		end = len(filtered)
	}

	for i, mod := range filtered[start:end] {
		idx := start + i
		cursor := "  "
		if idx == m.moduleCursor {
			cursor = m.term.ColoredIcon("", m.term.Color.Purple) + " "
		}

		catIcon := m.term.ModuleCategoryIcon(string(mod.Category))
		catColor := m.term.ModuleCategoryColor(string(mod.Category))
		typeIcon := m.term.ModuleTypeIcon(string(mod.Type))

		catTag := m.term.ColoredIcon(catIcon, catColor)
		typeTag := m.term.Dim(typeIcon)

		line := fmt.Sprintf("%s %s %s %s",
			cursor,
			catTag,
			typeTag,
			m.term.Dim(mod.RelPath))

		if idx == m.moduleCursor {
			line = fmt.Sprintf("%s %s %s %s",
				m.term.ColoredIcon("", m.term.Color.Purple),
				m.term.TagBg(string(mod.Category), m.term.Color.White, catColor),
				typeTag,
				m.term.Bold(mod.RelPath))
		}

		b.WriteString(line + "\n")
	}

	return b.String()
}

func (m *model) renderModuleDetail(mod scanner.Module) string {
	var b strings.Builder

	catColor := m.term.ModuleCategoryColor(string(mod.Category))
	catIcon := m.term.ModuleCategoryIcon(string(mod.Category))

	b.WriteString(m.term.IconH1("", mod.RelPath) + "\n\n")

	rows := [][]string{
		{m.term.ColoredIcon(catIcon, catColor) + " Category", string(mod.Category)},
		{m.term.ColoredIcon("", m.term.Color.Gray) + " Type", string(mod.Type)},
		{m.term.ColoredIcon("", m.term.Color.Gray) + " Domain", mod.Domain},
	}
	if mod.FileCount > 0 {
		rows = append(rows, []string{
			m.term.ColoredIcon("", m.term.Color.Gray) + " Files",
			fmt.Sprintf("%d", mod.FileCount),
		})
	}
	if mod.LineCount > 0 {
		rows = append(rows, []string{
			m.term.ColoredIcon("", m.term.Color.Gray) + " Lines",
			fmt.Sprintf("%d", mod.LineCount),
		})
	}

	for _, row := range rows {
		b.WriteString(fmt.Sprintf("  %-30s  %s\n", row[0], m.term.Bold(row[1])))
	}

	if info, ok := m.repo.Parsed[mod.Path]; ok {
		if info.Purpose != "" {
			b.WriteString("\n" + m.term.IconH2("", "Purpose") + "\n")
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
			b.WriteString("\n" + m.term.IconH2("", "Ownership") + "\n")
			for _, o := range info.Owns {
				b.WriteString(m.term.Dim("  " + o) + "\n")
			}
		}
		if len(info.Imports) > 0 {
			b.WriteString("\n" + m.term.IconH2("", "Imports") + "\n")
			maxShow := min(len(info.Imports), 10)
			for _, imp := range info.Imports[:maxShow] {
				b.WriteString(m.term.Dim("  " + imp) + "\n")
			}
			if len(info.Imports) > maxShow {
				b.WriteString(m.term.Dim(fmt.Sprintf("  … +%d more\n", len(info.Imports)-maxShow)))
			}
		}
		if info.HasOptions {
			b.WriteString("\n" + m.term.IconH2("", "Options") + "\n")
			b.WriteString("  " + m.term.Good("Declares options") + "\n")
		}
	} else {
		b.WriteString("\n" + m.term.Dim("  No parsed metadata available.") + "\n")
	}
	b.WriteString("\n" + m.term.Dim("   Esc back   Enter toggle"))
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

	good := total - len(dups) - len(orphans) - len(missing)
	if good < 0 {
		good = 0
	}

	b.WriteString("  " + m.term.IconH1("", "Health Overview") + "\n")
	b.WriteString(m.term.HealthBar(good, len(missing), len(dups)+len(orphans)) + "\n\n")

	b.WriteString(m.term.IconH2("", "Module Integrity") + "\n")
	integ := fmt.Sprintf("  Modules: %s %d NixOS + %s %d HM = %s %d\n",
		m.term.ColoredIcon("", m.term.Color.Purple), nixos,
		m.term.ColoredIcon("", m.term.Color.Cyan), hm,
		m.term.ColoredIcon("", m.term.Color.Green), total)
	b.WriteString(integ + "\n")

	b.WriteString(m.term.IconH2("", "Duplicate Imports") + "\n")
	if len(dups) == 0 {
		b.WriteString(fmt.Sprintf("  %s  No duplicates\n", m.term.Good("")))
	} else {
		count := min(len(dups), 8)
		for _, d := range dups[:count] {
			short := d
			if len(short) > 50 {
				short = short[:50] + "…"
			}
			b.WriteString(fmt.Sprintf("  %s  %s\n", m.term.ColoredIcon("", m.term.Color.Red), m.term.Dim(short)))
		}
		if len(dups) > count {
			b.WriteString(fmt.Sprintf("  %s  (+ %d more)\n", m.term.Dim("⋯"), len(dups)-count))
		}
	}
	b.WriteString("\n")

	b.WriteString(m.term.IconH2("", "Orphan Modules") + "\n")
	if len(orphans) == 0 {
		b.WriteString(fmt.Sprintf("  %s  None\n", m.term.Good("")))
	} else {
		for _, o := range orphans {
			b.WriteString(fmt.Sprintf("  %s  %s\n", m.term.ColoredIcon("", m.term.Color.Yellow), m.term.Dim(o)))
		}
	}
	b.WriteString("\n")

	b.WriteString(m.term.IconH2("", "Documentation") + "\n")
	if len(missing) == 0 {
		b.WriteString(fmt.Sprintf("  %s  All documented\n", m.term.Good("")))
	} else {
		count := min(len(missing), 6)
		for _, d := range missing[:count] {
			b.WriteString(fmt.Sprintf("  %s  %s\n", m.term.ColoredIcon("", m.term.Color.Yellow), m.term.Dim(d)))
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

	b.WriteString(m.term.IconH1("", fmt.Sprintf(" Domains (%d)", len(domains))) + "\n\n")

	for _, d := range domains {
		catIcon := m.term.ModuleCategoryIcon(d.Category)
		catColor := m.term.ModuleCategoryColor(d.Category)
		b.WriteString(fmt.Sprintf("  %s  %s  %s %s  %s  %s %d  %s %d\n",
			m.term.ColoredIcon("", catColor),
			m.term.Bold(d.Name),
			catIcon,
			m.term.TagBg(string(d.Category), m.term.Color.White, catColor),
			m.term.Dim(d.Path),
			m.term.ColoredIcon("", m.term.Color.Gray),
			d.FileCount,
			m.term.ColoredIcon("", m.term.Color.Gray),
			d.ModuleCount))
	}

	return b.String()
}

type gitLogEntry struct {
	Hash    string
	Author  string
	Date    string
	Message string
}

func (m *model) renderGitLog() string {
	var b strings.Builder

	gitDir := "--git-dir=" + m.repo.Root + "/.git"

	// Branch info
	branchOut, _ := exec.Command("git", gitDir, "rev-parse", "--abbrev-ref", "HEAD").Output()
	branch := strings.TrimSpace(string(branchOut))
	if branch == "" {
		branch = "unknown"
	}

	// Ahead/behind
	var behind, ahead int
	revList, _ := exec.Command("git", gitDir, "rev-list", "--left-right", "--count", "HEAD...@{u}").Output()
	parts := strings.Fields(string(revList))
	if len(parts) == 2 {
		behind, _ = strconv.Atoi(parts[0])
		ahead, _ = strconv.Atoi(parts[1])
	}

	b.WriteString(m.term.IconH1("", fmt.Sprintf(" Git: %s", branch)) + "\n\n")

	statusParts := []string{
		fmt.Sprintf("Branch: %s", m.term.Bold(branch)),
	}
	if ahead > 0 {
		statusParts = append(statusParts, fmt.Sprintf(" %d ahead", ahead))
	}
	if behind > 0 {
		statusParts = append(statusParts, fmt.Sprintf(" %d behind", behind))
	}
	if behind == 0 && ahead == 0 {
		statusParts = append(statusParts, m.term.Good("synced with origin"))
	}
	b.WriteString("  " + strings.Join(statusParts, "  ") + "\n\n")

	// Last commit info
	lastOut, _ := exec.Command("git", gitDir, "log", "-1", "--format=%H|%an|%ai|%s").Output()
	lastParts := strings.SplitN(strings.TrimSpace(string(lastOut)), "|", 4)
	if len(lastParts) == 4 {
		b.WriteString(m.term.IconH2("", "Latest Commit") + "\n")
		b.WriteString(fmt.Sprintf("  %s %s\n", m.term.ColoredIcon("", m.term.Color.Gray), m.term.Dim("Hash: ")+m.term.Bold(lastParts[0][:12])))
		shortMsg := lastParts[3]
		if len(shortMsg) > 60 {
			shortMsg = shortMsg[:60] + "…"
		}
		b.WriteString(fmt.Sprintf("  %s %s\n", m.term.ColoredIcon("", m.term.Color.Gray), m.term.Dim("Message: ")+m.term.Bold(shortMsg)))
		b.WriteString(fmt.Sprintf("  %s %s\n", m.term.ColoredIcon("", m.term.Color.Gray), m.term.Dim("Author: ")+lastParts[1]))
		b.WriteString(fmt.Sprintf("  %s %s\n", m.term.ColoredIcon("", m.term.Color.Gray), m.term.Dim("Date: ")+lastParts[2][:19]))
		b.WriteString("\n")
	}

	// Recent commits
	b.WriteString(m.term.IconH2("", "Recent Commits") + "\n")

	out, err := exec.Command("git", gitDir, "log", "--oneline", "-20", "--format=%h|%an|%ar|%s").Output()
	if err != nil {
		return b.String() + "  " + m.term.Dim("No git history available.")
	}

	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) == 0 || (len(lines) == 1 && lines[0] == "") {
		b.WriteString("  " + m.term.Dim("No commits yet."))
		return b.String()
	}

	for _, line := range lines {
		parts := strings.SplitN(line, "|", 4)
		if len(parts) < 4 {
			continue
		}
		msg := parts[3]
		if len(msg) > 50 {
			msg = msg[:50] + "…"
		}
		b.WriteString(fmt.Sprintf("  %s  %s  %s  %s\n",
			m.term.Dim(parts[0]),
			m.term.Dim(parts[1]),
			m.term.Dim(parts[2]),
			msg))
	}

	b.WriteString("\n")
	b.WriteString(m.term.Dim("   r refresh"))

	return b.String()
}

type genEntry struct {
	Number  int
	Date    string
	Current bool
}

func (m *model) renderGenerations() string {
	var b strings.Builder

	b.WriteString(m.term.IconH1("", "NixOS Generations") + "\n\n")

	out, err := exec.Command("nix-env", "--list-generations", "--profile", "/nix/var/nix/profiles/system").Output()
	if err != nil {
		// Try nix profile history as fallback
		altOut, altErr := exec.Command("nix", "profile", "history", "--profile", "/nix/var/nix/profiles/system").Output()
		if altErr != nil {
			b.WriteString("  " + m.term.Dim("No generation data available."))
			return b.String()
		}
		b.WriteString("  " + m.term.Dim(strings.TrimSpace(string(altOut))))
		return b.String()
	}

	genLines := strings.Split(strings.TrimSpace(string(out)), "\n")
	m.generations = nil
	for _, line := range genLines {
		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		num, err := strconv.Atoi(fields[0])
		if err != nil {
			continue
		}
		date := fields[1] + " " + fields[2]
		current := strings.Contains(line, "(current)")
		m.generations = append(m.generations, genEntry{Number: num, Date: date, Current: current})
	}

	if len(m.generations) == 0 {
		b.WriteString("  " + m.term.Dim("No generations found."))
		return b.String()
	}

	if m.genCursor >= len(m.generations) {
		m.genCursor = len(m.generations) - 1
	}

	contentHeight := m.height - 10
	if contentHeight < 3 {
		contentHeight = 3
	}

	start := m.genScrollOff
	end := start + contentHeight
	if end > len(m.generations) {
		end = len(m.generations)
	}

	for i, g := range m.generations[start:end] {
		idx := start + i
		icon := ""
		color := m.term.Color.Gray
		if g.Current {
			icon = ""
			color = m.term.Color.Purple
		}

		cursor := "  "
		isSelected := idx == m.genCursor
		if isSelected {
			cursor = m.term.ColoredIcon("", m.term.Color.Purple) + " "
		}

		var line string
		if isSelected {
			line = fmt.Sprintf("%s%s  Gen %d  %s",
				cursor,
				m.term.ColoredIcon(icon, color),
				g.Number,
				m.term.Bold(g.Date[:16]))
		} else {
			line = fmt.Sprintf("%s%s  Gen %d  %s",
				cursor,
				m.term.ColoredIcon(icon, color),
				g.Number,
				m.term.Dim(g.Date[:16]))
		}

		if g.Current {
			line += "  " + m.term.TagBg(" current ", m.term.Color.White, m.term.Color.Purple)
		}

		b.WriteString(line + "\n")
	}

	b.WriteString("\n")
	if m.genConfirm {
		gen := m.generations[m.genCursor]
		b.WriteString(m.term.Warn(fmt.Sprintf("  Rollback to generation %d? Enter to confirm, Esc to cancel.", gen.Number)) + "\n")
	} else {
		b.WriteString(m.term.Dim("  Enter: rollback  r: refresh  j/k: navigate") + "\n")
	}

	return b.String()
}

func (m *model) renderHelpBar() string {
	help := m.term.Dim("  ? help  ←/→ tab  r refresh  s sort  / filter  a actions  q quit")
	if m.helpVisible {
		help += "\n" + m.term.Dim("    IVALI Dashboard — Control Plane for NixOS Infrastructure")
		help += "\n" + m.term.Dim("    Tab / h,l: Switch panels (6 tabs)    Up/Down / j,k: Navigate")
		help += "\n" + m.term.Dim("    /: Filter modules    Esc: Clear filter    Backspace: Delete char")
		help += "\n" + m.term.Dim("    Enter: Module detail / Gen rollback    Esc: Back to list")
		help += "\n" + m.term.Dim("    s: Cycle sort (none → category → type → name → lines)")
		help += "\n" + m.term.Dim("    a: Toggle action mode    d: Rebuild system    x: Run doctor --fix")
		help += "\n" + m.term.Dim("    r: Refresh all data    g: Top    G: Bottom    q/Ctrl+C: Quit")
	}
	return help
}

func (m *model) renderActionMode() string {
	actions := []struct {
		icon  string
		key   string
		label string
		color lipgloss.TerminalColor
	}{
		{"", "d", "Rebuild system (nixos-rebuild switch)", m.term.Color.Green},
		{"", "x", "Run ivali doctor --fix", m.term.Color.Cyan},
		{"", "Esc", "Cancel", m.term.Color.Gray},
	}

	var b strings.Builder
	b.WriteString("  " + m.term.IconH1("⚡", "Actions") + "\n")

	for i, action := range actions {
		cursor := "  "
		if i == m.actionCursor {
			cursor = m.term.ColoredIcon("", m.term.Color.Purple) + " "
		}
		b.WriteString(fmt.Sprintf("  %s%s %s %s\n",
			cursor,
			m.term.ColoredIcon(action.icon, action.color),
			m.term.Bold(action.key),
			m.term.Dim(action.label)))
	}

	return b.String()
}

type errMsg error
type refreshDone time.Time
type refreshTick time.Time
type spinnerTick time.Time
type actionResultMsg struct {
	action string
	err    error
}
