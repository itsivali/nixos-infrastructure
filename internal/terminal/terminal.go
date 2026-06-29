package terminal

import (
	"fmt"
	"os"
	"strings"

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
	Theme    Theme
	Renderer *lipgloss.Renderer
	Width    int

	styles struct {
		header    lipgloss.Style
		section   lipgloss.Style
		ok        lipgloss.Style
		warn      lipgloss.Style
		fail      lipgloss.Style
		info      lipgloss.Style
		dim       lipgloss.Style
		key       lipgloss.Style
		value     lipgloss.Style
		separator lipgloss.Style
		helpCmd   lipgloss.Style
		helpDesc  lipgloss.Style
		splash    lipgloss.Style
	}
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

	for _, opt := range opts {
		opt(t)
	}

	lipgloss.SetColorProfile(termenv.TrueColor)

	adapt := func(light, dark string) lipgloss.TerminalColor {
		if t.Theme == ThemeLight {
			return lipgloss.Color(light)
		}
		if t.Theme == ThemeDark {
			return lipgloss.Color(dark)
		}
		return lipgloss.AdaptiveColor{Light: light, Dark: dark}
	}

	t.styles.header = lipgloss.NewStyle().
		Bold(true).
		Foreground(adapt("#7C3AED", "#7C3AED")).
		Padding(0, 1)

	t.styles.section = lipgloss.NewStyle().
		Bold(true).
		Foreground(adapt("#2563EB", "#60A5FA")).
		Padding(0, 1)

	t.styles.ok = lipgloss.NewStyle().
		Foreground(adapt("#16A34A", "#4ADE80"))

	t.styles.warn = lipgloss.NewStyle().
		Foreground(adapt("#D97706", "#FBBF24"))

	t.styles.fail = lipgloss.NewStyle().
		Foreground(adapt("#DC2626", "#F87171"))

	t.styles.info = lipgloss.NewStyle().
		Foreground(adapt("#2563EB", "#60A5FA"))

	t.styles.dim = lipgloss.NewStyle().
		Foreground(adapt("#6B7280", "#9CA3AF"))

	t.styles.key = lipgloss.NewStyle().
		Bold(true).
		Foreground(adapt("#374151", "#E5E7EB"))

	t.styles.value = lipgloss.NewStyle().
		Foreground(adapt("#6B7280", "#9CA3AF"))

	t.styles.separator = lipgloss.NewStyle().
		Foreground(adapt("#D1D5DB", "#374151"))

	t.styles.helpCmd = lipgloss.NewStyle().
		Bold(true).
		Foreground(adapt("#7C3AED", "#A78BFA"))

	t.styles.helpDesc = lipgloss.NewStyle().
		Foreground(adapt("#6B7280", "#9CA3AF"))

	t.styles.splash = lipgloss.NewStyle().
		Bold(true).
		Foreground(adapt("#7C3AED", "#A78BFA"))

	return t
}

func (t *Terminal) Header(text string) string {
	return t.styles.header.Render(text)
}

func (t *Terminal) Section(text string) string {
	sep := strings.Repeat("─", max(0, t.Width-lipgloss.Width(text)-4))
	return fmt.Sprintf("%s %s", t.styles.section.Render(text), t.styles.separator.Render(sep))
}

func (t *Terminal) OK(text string) string {
	return fmt.Sprintf("%s %s", t.styles.ok.Render("✓"), text)
}

func (t *Terminal) Warn(text string) string {
	return fmt.Sprintf("%s %s", t.styles.warn.Render("⚠"), text)
}

func (t *Terminal) Fail(text string) string {
	return fmt.Sprintf("%s %s", t.styles.fail.Render("✗"), text)
}

func (t *Terminal) Info(text string) string {
	return fmt.Sprintf("%s %s", t.styles.info.Render("ℹ"), text)
}

func (t *Terminal) Dim(text string) string {
	return t.styles.dim.Render(text)
}

func (t *Terminal) KeyValue(key, value string) string {
	return fmt.Sprintf("%-30s %s", t.styles.key.Render(key), t.styles.value.Render(value))
}

func (t *Terminal) BulletList(items []string) string {
	var b strings.Builder
	for _, item := range items {
		b.WriteString(fmt.Sprintf("  %s\n", item))
	}
	return b.String()
}

func (t *Terminal) Separator() string {
	return t.styles.separator.Render(strings.Repeat("─", t.Width))
}

func (t *Terminal) HelpCommand(name, description string) string {
	return fmt.Sprintf("  %s  %s",
		t.styles.helpCmd.Render(fmt.Sprintf("%-18s", name)),
		t.styles.helpDesc.Render(description),
	)
}

func (t *Terminal) Splash(text string) string {
	return t.styles.splash.Render(text)
}

func (t *Terminal) Markdown(text string) (string, error) {
	out, err := glamour.RenderWithEnvironmentConfig(text)
	if err != nil {
		return text, nil
	}
	return out, nil
}

func (t *Terminal) RenderSplash() string {
	var b strings.Builder

	title := t.Splash("◈  IVALI  ◈")
	subtitle := t.Dim("NixOS Infrastructure Control Plane")

	boxWidth := min(60, t.Width-4)

	line := strings.Repeat("─", boxWidth)

	b.WriteString(t.Dim("┌"+line+"┐") + "\n")
	b.WriteString(t.Dim("│ ") + title + t.Dim(" │") + "\n")
	b.WriteString(t.Dim("│ ") + subtitle + t.Dim(" │") + "\n")
	b.WriteString(t.Dim("├"+line+"┤") + "\n")

	b.WriteString(t.Dim("│") + "  " + t.styles.warn.Render("Not inside an infrastructure repository.") + "   " + t.Dim("│") + "\n")
	b.WriteString(t.Dim("│") + "\n")

	b.WriteString(t.Dim("│") + "  " + t.Info("") + " Clone your repo:" + "                  " + t.Dim("│") + "\n")
	b.WriteString(t.Dim("│") + "    ivali clone <url>" + "                    " + t.Dim("│") + "\n")
	b.WriteString(t.Dim("│") + "\n")
	b.WriteString(t.Dim("│") + "  " + t.Info("") + " Explore commands:" + "                 " + t.Dim("│") + "\n")
	b.WriteString(t.Dim("│") + "    ivali --help" + "                          " + t.Dim("│") + "\n")
	b.WriteString(t.Dim("│") + "\n")
	b.WriteString(t.Dim("│") + "  " + t.Info("") + " Initialize a new project:" + "            " + t.Dim("│") + "\n")
	b.WriteString(t.Dim("│") + "    ivali init" + "                            " + t.Dim("│") + "\n")
	b.WriteString(t.Dim("│") + "\n")
	b.WriteString(t.Dim("├"+line+"┤") + "\n")

	b.WriteString(t.Dim("│") + "  " + t.Dim("? help • q quit") + "                         " + t.Dim("│") + "\n")
	b.WriteString(t.Dim("└"+line+"┘") + "\n")

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
