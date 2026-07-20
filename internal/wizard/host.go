package wizard

import (
	"fmt"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

type hostStep int

const (
	stepWelcome hostStep = iota
	stepHostname
	stepUsername
	stepFeatures
	stepSSHKeys
	stepPreview
	stepGenerating
	stepDone
)

var featureList = []string{
	"secrets", "gitlab-runner", "bot",
	"tailscale", "tailscale-exit-node", "ssh",
}

var featureDesc = map[string]string{
	"secrets":             "SOPS age secrets",
	"gitlab-runner":       "Self-hosted GitLab CI runner",
	"bot":                 "Telegram bot control plane",
	"tailscale":           "Zero-trust VPN networking",
	"tailscale-exit-node": "Advertise as Tailscale exit node",
	"ssh":                 "SSH daemon (Tailscale-only)",
}

type hostModel struct {
	term          *terminal.Terminal
	step          hostStep
	width         int
	height        int
	hostName      string
	userName      string
	features      map[string]bool
	sshKeys       string
	repoPath      string
	textBuf       []rune
	featureCursor int
	sshLine       int
	done          bool
}

func NewHostWizard(term *terminal.Terminal) tea.Model {
	features := make(map[string]bool)
	for _, f := range featureList {
		features[f] = true
	}
	userName := os.Getenv("USER")
	if userName == "" {
		userName = "ivali"
	}
	home, _ := os.UserHomeDir()
	repoPath := home + "/nixos-infrastructure"

	return &hostModel{
		term:     term,
		step:     stepWelcome,
		features: features,
		userName: userName,
		repoPath: repoPath,
		textBuf:  []rune{},
	}
}

func (m *hostModel) Init() tea.Cmd { return nil }

var (
	labelStyle  = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#A78BFA"))
	dimStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("#9CA3AF"))
	goodStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("#4ADE80"))
	cyanStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("#22D3EE"))
	purpleStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#A78BFA"))
	boldStyle   = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#F3F4F6"))
)

func (m *hostModel) updateTextInput(msg tea.KeyMsg) {
	switch msg.String() {
	case "enter":
		m.commitTextInput()
	case "backspace":
		if len(m.textBuf) > 0 {
			m.textBuf = m.textBuf[:len(m.textBuf)-1]
		}
	default:
		if len(msg.String()) == 1 && msg.String() != " " {
			m.textBuf = append(m.textBuf, rune(msg.String()[0]))
		}
	}
}

func (m *hostModel) commitTextInput() {
	switch m.step {
	case stepHostname:
		m.hostName = string(m.textBuf)
		m.textBuf = []rune{}
		if m.hostName != "" {
			m.step = stepUsername
		}
	case stepUsername:
		val := string(m.textBuf)
		if val != "" {
			m.userName = val
		}
		m.textBuf = []rune{}
		m.step = stepFeatures
		m.featureCursor = 0
	}
}

func (m *hostModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.KeyMsg:
		if m.done {
			if msg.String() == "enter" || msg.String() == "q" || msg.String() == "esc" {
				return m, tea.Quit
			}
			return m, nil
		}
		switch m.step {
		case stepWelcome:
			if msg.String() == "enter" {
				m.step = stepHostname
				m.textBuf = []rune{}
			} else if msg.String() == "q" || msg.String() == "ctrl+c" {
				return m, tea.Quit
			}
		case stepHostname:
			if msg.String() == "esc" {
				m.step = stepWelcome
				m.textBuf = []rune{}
			} else {
				m.updateTextInput(msg)
			}
		case stepUsername:
			if msg.String() == "esc" {
				m.step = stepHostname
				m.textBuf = []rune(m.hostName)
			} else {
				m.updateTextInput(msg)
			}
		case stepFeatures:
			switch msg.String() {
			case "esc":
				m.step = stepUsername
				m.textBuf = []rune(m.userName)
			case "up", "k":
				if m.featureCursor > 0 {
					m.featureCursor--
				}
			case "down", "j":
				if m.featureCursor < len(featureList)-1 {
					m.featureCursor++
				}
			case " ":
				f := featureList[m.featureCursor]
				m.features[f] = !m.features[f]
			case "enter":
				m.step = stepSSHKeys
				m.textBuf = []rune{}
				m.sshLine = 0
			}
		case stepSSHKeys:
			switch msg.String() {
			case "esc":
				m.step = stepFeatures
			case "enter":
				val := string(m.textBuf)
				if val != "" {
					if m.sshLine == 0 {
						m.sshKeys = val
					} else {
						m.sshKeys += "\n" + val
					}
					m.sshLine++
					m.textBuf = []rune{}
				} else {
					m.step = stepPreview
				}
			case "backspace":
				if len(m.textBuf) > 0 {
					m.textBuf = m.textBuf[:len(m.textBuf)-1]
				} else if m.sshLine > 0 {
					m.sshLine--
				}
			default:
				if len(msg.String()) == 1 {
					m.textBuf = append(m.textBuf, rune(msg.String()[0]))
				}
			}
		case stepPreview:
			switch msg.String() {
			case "esc":
				m.step = stepSSHKeys
				m.textBuf = []rune{}
				m.sshLine = 0
			case "enter":
				m.step = stepGenerating
				return m, func() tea.Msg { return generationResult{} }
			case "e":
				m.step = stepHostname
				m.textBuf = []rune(m.hostName)
			}
		case stepGenerating:
			m.step = stepDone
			m.done = true
		case stepDone:
			if msg.String() == "enter" || msg.String() == "q" || msg.String() == "esc" {
				return m, tea.Quit
			}
		}
	}
	return m, nil
}

type generationResult struct{}

func (m *hostModel) View() string {
	var b strings.Builder
	switch m.step {
	case stepWelcome:
		b.WriteString(m.renderWelcome())
	case stepHostname:
		b.WriteString(m.renderTextInput("Host name", "Enter the hostname (e.g. prague, tokyo)", m.hostName, false))
	case stepUsername:
		b.WriteString(m.renderTextInput("Username", "Primary user for this machine", string(m.textBuf), true))
	case stepFeatures:
		b.WriteString(m.renderFeatures())
	case stepSSHKeys:
		b.WriteString(m.renderSSHKeys())
	case stepPreview:
		b.WriteString(m.renderPreview())
	case stepGenerating:
		b.WriteString(m.renderGenerating())
	case stepDone:
		b.WriteString(m.renderDone())
	}
	b.WriteString("\n\n" + dimStyle.Render("   Esc back   ↵ Enter confirm   q quit"))
	return b.String()
}

func (m *hostModel) renderWelcome() string {
	var b strings.Builder
	b.WriteString("\n\n")
	b.WriteString("  " + purpleStyle.Render("") + boldStyle.Render("  Host Bootstrap Wizard") + "\n\n")
	b.WriteString("  " + dimStyle.Render("This wizard will guide you through creating a new") + "\n")
	b.WriteString("  " + dimStyle.Render("laptop host configuration for your NixOS infrastructure.") + "\n\n")
	b.WriteString("  " + dimStyle.Render("You will configure:") + "\n")
	b.WriteString("  " + dimStyle.Render("    Host identity (name, user)") + "\n")
	b.WriteString("  " + dimStyle.Render("    Features (secrets, bot, Tailscale, SSH, GitLab Runner)") + "\n")
	b.WriteString("  " + dimStyle.Render("    SSH authorized keys") + "\n\n")
	b.WriteString("  " + dimStyle.Render("Press  Enter to begin"))
	return b.String()
}

func (m *hostModel) renderTextInput(title, prompt, current string, optional bool) string {
	var b strings.Builder
	b.WriteString("\n\n")
	b.WriteString("  " + labelStyle.Render(title) + "\n\n")
	b.WriteString("  " + dimStyle.Render(prompt) + "\n\n")
	val := current
	if val == "" {
		val = string(m.textBuf)
	}
	if val != "" || len(m.textBuf) > 0 {
		b.WriteString("  " + boldStyle.Render(val) + "\n")
	} else {
		b.WriteString("  " + dimStyle.Render("▎") + "\n")
	}
	if optional {
		b.WriteString("\n  " + dimStyle.Render("Leave empty for default: "+m.userName))
	}
	return b.String()
}

func (m *hostModel) renderFeatures() string {
	var b strings.Builder
	b.WriteString("\n\n")
	b.WriteString("  " + labelStyle.Render("Features") + "\n\n")
	b.WriteString("  " + dimStyle.Render("Use ↑/↓ to navigate, Space to toggle, Enter to confirm") + "\n\n")
	for i, f := range featureList {
		cursor := "  "
		if i == m.featureCursor {
			cursor = purpleStyle.Render(" ")
		}
		checked := m.features[f]
		box := dimStyle.Render("")
		if checked {
			box = goodStyle.Render("")
		}
		b.WriteString(fmt.Sprintf("  %s%s %s\n", cursor, box, featureDesc[f]))
	}
	return b.String()
}

func (m *hostModel) renderSSHKeys() string {
	var b strings.Builder
	b.WriteString("\n\n")
	b.WriteString("  " + labelStyle.Render("SSH Authorized Keys") + "\n\n")
	b.WriteString("  " + dimStyle.Render("Enter each public key on a new line.") + "\n")
	b.WriteString("  " + dimStyle.Render("Press Enter on an empty line to continue.") + "\n\n")
	if m.sshKeys != "" {
		for _, line := range strings.Split(m.sshKeys, "\n") {
			b.WriteString("  " + dimStyle.Render("  "+cyanStyle.Render("")+" "+line) + "\n")
		}
	}
	val := string(m.textBuf)
	b.WriteString("  " + dimStyle.Render("  "+cyanStyle.Render("")+" "+val+"▎") + "\n")
	return b.String()
}

func (m *hostModel) renderPreview() string {
	var b strings.Builder
	b.WriteString("\n\n")
	b.WriteString("  " + labelStyle.Render("Preview") + "\n\n")
	b.WriteString("  " + dimStyle.Render("Review your selections.") + "\n\n")
	b.WriteString(fmt.Sprintf("  %s %s\n", dimStyle.Render("Hostname:"), boldStyle.Render(m.hostName)))
	b.WriteString(fmt.Sprintf("  %s %s\n", dimStyle.Render("Username:"), boldStyle.Render(m.userName)))

	var enabled, disabled []string
	for _, f := range featureList {
		if m.features[f] {
			enabled = append(enabled, f)
		} else {
			disabled = append(disabled, f)
		}
	}
	if len(enabled) > 0 {
		b.WriteString("  " + dimStyle.Render("Features:   ") + goodStyle.Render(strings.Join(enabled, ", ")) + "\n")
	}
	if len(disabled) > 0 {
		b.WriteString("  " + dimStyle.Render("Disabled:   ") + dimStyle.Render(strings.Join(disabled, ", ")) + "\n")
	}
	if m.sshKeys != "" {
		b.WriteString("  " + dimStyle.Render("SSH keys:") + "\n")
		for _, line := range strings.Split(m.sshKeys, "\n") {
			if len(line) > 60 {
				line = line[:60] + "…"
			}
			b.WriteString("  " + dimStyle.Render("    "+line) + "\n")
		}
	}
	b.WriteString("\n  " + dimStyle.Render("Press   Enter to generate  |   Esc to edit  |  e to restart"))
	return b.String()
}

func (m *hostModel) renderGenerating() string {
	return "\n\n" + "  " + cyanStyle.Render(" Generating host configuration...")
}

func (m *hostModel) renderDone() string {
	var b strings.Builder
	b.WriteString("\n\n")
	b.WriteString("  " + goodStyle.Render("") + boldStyle.Render("  Host configuration generated!") + "\n\n")
	b.WriteString("  " + dimStyle.Render("Files created:") + "\n")
	b.WriteString("  " + dimStyle.Render("  hosts/"+m.hostName+"/"+m.hostName+".nix") + "\n")
	b.WriteString("  " + dimStyle.Render("  hosts/"+m.hostName+"/hardware-configuration.nix") + "\n")
	b.WriteString("  " + dimStyle.Render("  secrets/hosts/"+m.hostName+".yaml") + "\n\n")
	b.WriteString("  " + dimStyle.Render("Next steps:") + "\n")
	b.WriteString("  " + dimStyle.Render("  1. Run: sudo nixos-generate-config --show-hardware-config > hosts/"+m.hostName+"/hardware-configuration.nix") + "\n")
	b.WriteString("  " + dimStyle.Render("  2. Run: ivali scan") + "\n")
	b.WriteString("  " + dimStyle.Render("  3. Run: sudo nixos-rebuild switch --flake .#"+m.hostName) + "\n\n")
	b.WriteString("  " + dimStyle.Render("Press Enter or q to quit"))
	return b.String()
}
