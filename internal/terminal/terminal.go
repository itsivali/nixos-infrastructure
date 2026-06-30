package terminal

import (
	"fmt"
	"os"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/charmbracelet/glamour"
	"github.com/charmbracelet/lipgloss"
	"github.com/muesli/termenv"
	"golang.org/x/term"
)

type Theme string

const (
	ThemeAuto  Theme = "auto"
	ThemeLight Theme = "light"
	ThemeDark  Theme = "dark"
)

type Terminal struct {
	Theme  Theme
	Width  int
	DarkBg bool
	Color  ColorPalette
	lip    *lipgloss.Renderer
}

type ColorPalette struct {
	Purple  lipgloss.TerminalColor
	Blue    lipgloss.TerminalColor
	Green   lipgloss.TerminalColor
	Yellow  lipgloss.TerminalColor
	Red     lipgloss.TerminalColor
	Cyan    lipgloss.TerminalColor
	Gray    lipgloss.TerminalColor
	White   lipgloss.TerminalColor
	Surface lipgloss.TerminalColor
	Border  lipgloss.TerminalColor
}

type Option func(*Terminal)

func WithTheme(theme string) Option {
	return func(t *Terminal) {
		t.Theme = Theme(theme)
	}
}

func New(opts ...Option) *Terminal {
	t := &Terminal{
		Theme: ThemeAuto,
		Width: 80,
	}

	if term.IsTerminal(int(os.Stdout.Fd())) {
		w, _, err := term.GetSize(int(os.Stdout.Fd()))
		if err == nil && w > 0 {
			t.Width = w
		}
	}

	dark := termenv.HasDarkBackground()
	t.DarkBg = dark

	for _, opt := range opts {
		opt(t)
	}

	if t.Theme == ThemeLight {
		t.DarkBg = false
	} else if t.Theme == ThemeDark {
		t.DarkBg = true
	}

	lipgloss.SetColorProfile(termenv.TrueColor)

	t.lip = lipgloss.DefaultRenderer()

	t.Color = ColorPalette{
		Purple:  t.adapt("#7C3AED", "#A78BFA"),
		Blue:    t.adapt("#2563EB", "#60A5FA"),
		Green:   t.adapt("#16A34A", "#4ADE80"),
		Yellow:  t.adapt("#D97706", "#FBBF24"),
		Red:     t.adapt("#DC2626", "#F87171"),
		Cyan:    t.adapt("#0891B2", "#22D3EE"),
		Gray:    t.adapt("#6B7280", "#9CA3AF"),
		White:   t.adapt("#1F2937", "#F3F4F6"),
		Surface: t.adapt("#F3F4F6", "#1F2937"),
		Border:  t.adapt("#D1D5DB", "#374151"),
	}

	return t
}

func (t *Terminal) WithTheme(theme string) *Terminal {
	return New(WithTheme(theme))
}

func (t *Terminal) adapt(light, dark string) lipgloss.TerminalColor {
	if t.Theme == ThemeLight || !t.DarkBg {
		return lipgloss.Color(light)
	}
	return lipgloss.Color(dark)
}

func (t *Terminal) adaptBg(light, dark string) lipgloss.TerminalColor {
	if t.Theme == ThemeLight || !t.DarkBg {
		return lipgloss.Color(light)
	}
	return lipgloss.Color(dark)
}

func (t *Terminal) styleFromPalette(c lipgloss.TerminalColor) lipgloss.Style {
	return lipgloss.NewStyle().Foreground(c)
}

func (t *Terminal) Header(text string) string {
	return lipgloss.NewStyle().
		Bold(true).
		Foreground(t.Color.Purple).
		Padding(0, 1).
		Render(text)
}

func (t *Terminal) H1(text string) string {
	return lipgloss.NewStyle().
		Bold(true).
		Foreground(t.Color.White).
		Padding(0, 1).
		Render(text)
}

func (t *Terminal) H2(text string) string {
	return lipgloss.NewStyle().
		Bold(true).
		Foreground(t.Color.Purple).
		Padding(0, 1).
		Render("  " + text)
}

func (t *Terminal) IconH1(icon string, text string) string {
	return fmt.Sprintf("  %s %s",
		lipgloss.NewStyle().Bold(true).Foreground(t.Color.Purple).Render(icon),
		lipgloss.NewStyle().Bold(true).Foreground(t.Color.White).Render(text))
}

func (t *Terminal) IconH2(icon string, text string) string {
	return fmt.Sprintf("  %s %s",
		lipgloss.NewStyle().Foreground(t.Color.Purple).Render(icon),
		lipgloss.NewStyle().Bold(true).Foreground(t.Color.Cyan).Render(text))
}

func (t *Terminal) Section(text string) string {
	sep := strings.Repeat("─", max(0, t.Width-utf8.RuneCountInString(text)-6))
	return fmt.Sprintf("  %s %s",
		lipgloss.NewStyle().Bold(true).Foreground(t.Color.Blue).Render(text),
		lipgloss.NewStyle().Foreground(t.Color.Border).Render(sep))
}

func (t *Terminal) Subsection(text string) string {
	return fmt.Sprintf("  %s",
		lipgloss.NewStyle().Bold(true).Foreground(t.Color.Cyan).Render(" "+text))
}

func (t *Terminal) Good(text string) string {
	return fmt.Sprintf("  %s %s",
		lipgloss.NewStyle().Foreground(t.Color.Green).Render(""),
		text)
}

func (t *Terminal) Bad(text string) string {
	return fmt.Sprintf("  %s %s",
		lipgloss.NewStyle().Foreground(t.Color.Red).Render(""),
		text)
}

func (t *Terminal) Warn(text string) string {
	return fmt.Sprintf("  %s %s",
		lipgloss.NewStyle().Foreground(t.Color.Yellow).Render(""),
		text)
}

func (t *Terminal) Info(text string) string {
	return fmt.Sprintf("  %s %s",
		lipgloss.NewStyle().Foreground(t.Color.Blue).Render(""),
		text)
}

func (t *Terminal) Dim(text string) string {
	return lipgloss.NewStyle().Foreground(t.Color.Gray).Render(text)
}

func (t *Terminal) Bold(text string) string {
	return lipgloss.NewStyle().Bold(true).Foreground(t.Color.White).Render(text)
}

func (t *Terminal) Code(text string) string {
	return lipgloss.NewStyle().
		Foreground(t.Color.Cyan).
		Background(t.adaptBg("#E8E8E8", "#2D2D2D")).
		Padding(0, 1).
		Render(text)
}

func (t *Terminal) KeyValue(key, value string, extra ...string) string {
	extraStr := ""
	if len(extra) > 0 && extra[0] != "" {
		extraStr = "  " + lipgloss.NewStyle().Foreground(t.Color.Gray).Render(extra[0])
	}
	return fmt.Sprintf("  %s %s%s",
		lipgloss.NewStyle().Bold(true).Foreground(t.Color.White).Render(fmt.Sprintf("%-28s", key)),
		lipgloss.NewStyle().Foreground(t.Color.Gray).Render(value),
		extraStr,
	)
}

func (t *Terminal) HelpCommand(name, description string) string {
	return fmt.Sprintf("  %s  %s",
		lipgloss.NewStyle().Bold(true).Foreground(t.Color.Purple).Render(fmt.Sprintf("%-20s", name)),
		lipgloss.NewStyle().Foreground(t.Color.Gray).Render(description),
	)
}

func (t *Terminal) Box(title string, content string, style lipgloss.TerminalColor) string {
	width := min(t.Width-4, 72)

	border := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(style).
		Width(width).
		Padding(0, 1)

	if title != "" {
		header := lipgloss.NewStyle().Bold(true).Foreground(style).Render(title)
		content = header + "\n" + content
	}

	return "  " + border.Render(content)
}

func (t *Terminal) SuccessBox(content string) string {
	return t.Box("", content, t.Color.Green)
}

func (t *Terminal) ErrorBox(content string) string {
	return t.Box("", content, t.Color.Red)
}

func (t *Terminal) InfoBox(content string) string {
	return t.Box("", content, t.Color.Blue)
}

func (t *Terminal) Table(header []string, rows [][]string) string {
	if len(rows) == 0 {
		return t.Dim("  (none)")
	}

	cols := len(header)
	widths := make([]int, cols)
	for i, h := range header {
		widths[i] = utf8.RuneCountInString(h)
	}
	for _, row := range rows {
		for i, cell := range row {
			if i < cols {
				widths[i] = max(widths[i], utf8.RuneCountInString(cell))
			}
		}
	}

	totalWidth := 0
	for _, w := range widths {
		totalWidth += w + 3
	}
	totalWidth = min(totalWidth+1, t.Width-4)

	var b strings.Builder

	renderCell := func(cell string, width int, isHeader bool) string {
		cell = fmt.Sprintf(" %-*s ", width, cell)
		if isHeader {
			return lipgloss.NewStyle().
				Bold(true).
				Foreground(t.Color.White).
				Render(cell)
		}
		return lipgloss.NewStyle().
			Foreground(t.Color.Gray).
			Render(cell)
	}

	sepParts := make([]string, cols)
	for i, w := range widths {
		sepParts[i] = strings.Repeat("─", w+2)
	}
	sep := lipgloss.NewStyle().Foreground(t.Color.Border).Render(" " + strings.Join(sepParts, "─") + " ")
	_ = sep

	headerCells := make([]string, cols)
	for i, h := range header {
		headerCells[i] = renderCell(h, widths[i], true)
	}
	b.WriteString("  " + strings.Join(headerCells, " ") + "\n")

	for _, row := range rows {
		cells := make([]string, cols)
		for i, cell := range row {
			if i < cols {
				cells[i] = renderCell(cell, widths[i], false)
			}
		}
		b.WriteString("  " + strings.Join(cells, " ") + "\n")
	}

	return b.String()
}

func (t *Terminal) BulletList(items []string, indent int) string {
	prefix := strings.Repeat("  ", indent)
	var b strings.Builder
	for _, item := range items {
		b.WriteString(fmt.Sprintf("%s  %s %s\n", prefix,
			lipgloss.NewStyle().Foreground(t.Color.Gray).Render("•"),
			item))
	}
	return b.String()
}

func (t *Terminal) CheckList(items []CheckItem) string {
	var b strings.Builder
	for _, item := range items {
		var icon, label string
		switch item.Status {
		case StatusPass:
			icon = lipgloss.NewStyle().Foreground(t.Color.Green).Render("")
			label = lipgloss.NewStyle().Foreground(t.Color.Gray).Render(item.Label)
		case StatusFail:
			icon = lipgloss.NewStyle().Foreground(t.Color.Red).Render("")
			label = lipgloss.NewStyle().Foreground(t.Color.Red).Render(item.Label)
		case StatusWarn:
			icon = lipgloss.NewStyle().Foreground(t.Color.Yellow).Render("")
			label = lipgloss.NewStyle().Foreground(t.Color.Yellow).Render(item.Label)
		default:
			icon = lipgloss.NewStyle().Foreground(t.Color.Gray).Render("")
			label = lipgloss.NewStyle().Foreground(t.Color.Gray).Render(item.Label)
		}

		b.WriteString(fmt.Sprintf("  %s %s", icon, label))
		if item.Detail != "" {
			b.WriteString(fmt.Sprintf("  %s", lipgloss.NewStyle().Foreground(t.Color.Gray).Render(item.Detail)))
		}
		b.WriteString("\n")
	}
	return b.String()
}

type CheckStatus int

const (
	StatusPending CheckStatus = iota
	StatusPass
	StatusWarn
	StatusFail
)

type CheckItem struct {
	Label  string
	Status CheckStatus
	Detail string
}

func (t *Terminal) Summary(label string, value string) string {
	return fmt.Sprintf("  %s: %s",
		lipgloss.NewStyle().Bold(true).Foreground(t.Color.White).Render(label),
		value)
}

func (t *Terminal) Count(count int, total int) string {
	ratio := float64(count) / float64(max(total, 1))
	width := 20
	filled := int(ratio * float64(width))

	bar := "["
	for i := 0; i < width; i++ {
		if i < filled {
			bar += "■"
		} else {
			bar += "·"
		}
	}
	bar += "]"

	color := t.Color.Green
	if ratio < 0.5 {
		color = t.Color.Yellow
	}
	if ratio < 0.25 {
		color = t.Color.Red
	}

	return fmt.Sprintf("  %s %d/%d",
		lipgloss.NewStyle().Foreground(color).Render(bar),
		count, total)
}

func (t *Terminal) Timestamp() string {
	return t.Dim(time.Now().Format("15:04:05"))
}

func (t *Terminal) Separator() string {
	return "  " + lipgloss.NewStyle().Foreground(t.Color.Border).Render(strings.Repeat("─", min(t.Width-4, 68)))
}

func (t *Terminal) Blank() string {
	return ""
}

// ── Nerd Font Icons ────────────────────────────────────────────────────

type CategoryIcon string

const (
	IconNixOS       CategoryIcon = ""
	IconHomeManager CategoryIcon = ""
	IconHost        CategoryIcon = ""
	IconPackage     CategoryIcon = ""
	IconLibrary     CategoryIcon = ""
	IconConfig      CategoryIcon = ""
	IconScript      CategoryIcon = ""
	IconSecret      CategoryIcon = ""
	IconTest        CategoryIcon = ""
	IconDefault     CategoryIcon = ""
	IconModule      CategoryIcon = ""
	IconDomain      CategoryIcon = ""
	IconHealth      CategoryIcon = ""
	IconGraph       CategoryIcon = ""
	IconSearch      CategoryIcon = ""
	IconRefresh     CategoryIcon = ""
	IconHelp        CategoryIcon = ""
	IconQuit        CategoryIcon = ""
	IconFilter      CategoryIcon = ""
	IconSort        CategoryIcon = ""
	IconDetail      CategoryIcon = ""
	IconFolder      CategoryIcon = ""
	IconFile        CategoryIcon = ""
	IconGit         CategoryIcon = ""
	IconNix         CategoryIcon = ""
)

func (t *Terminal) ModuleCategoryIcon(cat string) string {
	m := map[string]string{
		"nixos":        string(IconNixOS),
		"home-manager": string(IconHomeManager),
		"host":         string(IconHost),
		"package":      string(IconPackage),
		"library":      string(IconLibrary),
		"config":       string(IconConfig),
		"script":       string(IconScript),
		"secret":       string(IconSecret),
		"test":         string(IconTest),
	}
	icon, ok := m[cat]
	if !ok {
		return string(IconDefault)
	}
	return icon
}

func (t *Terminal) ModuleCategoryColor(cat string) lipgloss.TerminalColor {
	m := map[string]lipgloss.TerminalColor{
		"nixos":        t.Color.Purple,
		"home-manager": t.Color.Cyan,
		"host":         t.Color.Blue,
		"package":      t.Color.Yellow,
		"library":      t.Color.Green,
		"config":       t.Color.Gray,
		"script":       t.Color.Yellow,
		"secret":       t.Color.Red,
		"test":         t.Color.Cyan,
	}
	c, ok := m[cat]
	if !ok {
		return t.Color.Gray
	}
	return c
}

func (t *Terminal) ModuleTypeIcon(typ string) string {
	m := map[string]string{
		"entry":   "",
		"options": "",
		"regular": "",
		"private": "",
		"subdir":  "",
	}
	icon, ok := m[typ]
	if !ok {
		return ""
	}
	return icon
}

func (t *Terminal) ColoredIcon(icon string, color lipgloss.TerminalColor) string {
	return lipgloss.NewStyle().Foreground(color).Render(icon)
}

// HealthBar renders a colored progress bar with Nerd Font block chars.
func (t *Terminal) HealthBar(good, warn, bad int) string {
	total := good + warn + bad
	if total == 0 {
		total = 1
	}
	width := min(30, t.Width-12)
	goodW := int(float64(good) / float64(total) * float64(width))
	warnW := int(float64(warn) / float64(total) * float64(width))
	badW := width - goodW - warnW
	if badW < 0 {
		badW = 0
	}

	var b strings.Builder
	g := strings.Repeat("█", goodW)
	w := strings.Repeat("█", warnW)
	ba := strings.Repeat("█", badW)

	if goodW > 0 {
		b.WriteString(lipgloss.NewStyle().Foreground(t.Color.Green).Render(g))
	}
	if warnW > 0 {
		b.WriteString(lipgloss.NewStyle().Foreground(t.Color.Yellow).Render(w))
	}
	if badW > 0 {
		b.WriteString(lipgloss.NewStyle().Foreground(t.Color.Red).Render(ba))
	}

	return fmt.Sprintf("  %s  %d✓ %d⚠ %d✗",
		b.String(), good, warn, bad)
}

// Tag renders a colored badge/tag.
func (t *Terminal) Tag(text string, color lipgloss.TerminalColor) string {
	return lipgloss.NewStyle().
		Foreground(color).
		Padding(0, 1).
		Render(text)
}

// TagBg renders a badge with a background fill.
func (t *Terminal) TagBg(text string, fg, bg lipgloss.TerminalColor) string {
	return lipgloss.NewStyle().
		Foreground(fg).
		Background(bg).
		Padding(0, 1).
		Render(text)
}

// IconText returns text with a colored icon prefix.
func (t *Terminal) IconText(icon string, text string, color lipgloss.TerminalColor) string {
	return fmt.Sprintf("%s %s",
		lipgloss.NewStyle().Foreground(color).Render(icon),
		lipgloss.NewStyle().Foreground(t.Color.White).Render(text),
	)
}

// AnimatedSpinner returns a spinner frame based on elapsed time.
func AnimatedSpinner(t time.Time) string {
	frames := []string{"", "", "", ""}
	idx := int(time.Since(t).Milliseconds() / 150 % int64(len(frames)))
	return frames[idx]
}

func (t *Terminal) Markdown(text string) (string, error) {
	out, err := glamour.RenderWithEnvironmentConfig(text)
	if err != nil {
		return text, nil
	}
	return out, nil
}

func (t *Terminal) RenderSplash() string {
	purple := t.Color.Purple
	gray := t.Color.Gray
	border := t.Color.Border

	title := lipgloss.NewStyle().Bold(true).Foreground(purple).Render("  IVALI  ")
	subtitle := lipgloss.NewStyle().Foreground(gray).Render("NixOS Infrastructure Control Plane")

	boxWidth := min(56, t.Width-6)
	line := strings.Repeat("─", boxWidth)

	var b strings.Builder
	bl := lipgloss.NewStyle().Foreground(border)

	b.WriteString(bl.Render("  ┌"+line+"┐") + "\n")
	b.WriteString(bl.Render("  │ ") + title + bl.Render(" │") + "\n")
	b.WriteString(bl.Render("  │ ") + subtitle + bl.Render(" │") + "\n")
	b.WriteString(bl.Render("  ├"+line+"┤") + "\n")

	warnText := lipgloss.NewStyle().Foreground(t.Color.Yellow).Render("Not inside an infrastructure repository.")
	b.WriteString(bl.Render("  │ ") + warnText + bl.Render("    │") + "\n")
	b.WriteString(bl.Render("  │") + "\n")

	infoStyle := lipgloss.NewStyle().Foreground(t.Color.Blue)
	cmdStyle := lipgloss.NewStyle().Foreground(t.Color.Cyan)

	b.WriteString(bl.Render("  │ ") + infoStyle.Render("") + " Clone your repo:" + strings.Repeat(" ", boxWidth-20) + bl.Render("│") + "\n")
	b.WriteString(bl.Render("  │   ") + cmdStyle.Render("ivali clone <url>") + strings.Repeat(" ", boxWidth-22) + bl.Render("│") + "\n")
	b.WriteString(bl.Render("  │") + "\n")
	b.WriteString(bl.Render("  │ ") + infoStyle.Render("") + " Explore commands:" + strings.Repeat(" ", boxWidth-21) + bl.Render("│") + "\n")
	b.WriteString(bl.Render("  │   ") + cmdStyle.Render("ivali --help") + strings.Repeat(" ", boxWidth-16) + bl.Render("│") + "\n")
	b.WriteString(bl.Render("  │") + "\n")
	b.WriteString(bl.Render("  │ ") + infoStyle.Render("") + " Quick start a new project:" + strings.Repeat(" ", boxWidth-27) + bl.Render("│") + "\n")
	b.WriteString(bl.Render("  │   ") + cmdStyle.Render("ivali init") + strings.Repeat(" ", boxWidth-15) + bl.Render("│") + "\n")
	b.WriteString(bl.Render("  │") + "\n")
	b.WriteString(bl.Render("  ├"+line+"┤") + "\n")
	b.WriteString(bl.Render("  │ ") + lipgloss.NewStyle().Foreground(gray).Render(" help    q quit") + strings.Repeat(" ", boxWidth-23) + bl.Render("│") + "\n")
	b.WriteString(bl.Render("  └"+line+"┘") + "\n")

	return b.String()
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

func IsInteractive() bool {
	stat, _ := os.Stdout.Stat()
	return (stat.Mode() & os.ModeCharDevice) != 0
}
