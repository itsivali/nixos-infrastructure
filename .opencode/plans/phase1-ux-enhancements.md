# Phase 1 UX Enhancements — Implementation Plan

## Files to Create

### 1. `internal/commands/progress.go` — Shared progress helpers

```go
package commands

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

func confirmAction(t *terminal.Terminal, message string) bool {
	if !terminal.IsInteractive() {
		return true
	}
	fmt.Printf("  %s %s %s ",
		t.ColoredIcon("", t.Color.Yellow),
		message,
		t.Dim("[y/N]"))
	var response string
	fmt.Scanln(&response)
	response = strings.TrimSpace(strings.ToLower(response))
	return response == "y" || response == "yes"
}

func runWithTimer(t *terminal.Terminal, desc string, fn func() error) error {
	start := time.Now()
	fmt.Printf("  %s %s\n",
		t.ColoredIcon("", t.Color.Cyan),
		desc)

	err := fn()

	elapsed := time.Since(start)
	mins := int(elapsed.Minutes())
	secs := int(elapsed.Seconds()) % 60
	timing := fmt.Sprintf("%dm%ds", mins, secs)

	fmt.Print("\033[1A\033[K")
	if err != nil {
		fmt.Printf("  %s %s  %s\n",
			t.ColoredIcon("", t.Color.Red),
			desc,
			t.Dim(timing))
	} else {
		fmt.Printf("  %s %s  %s\n",
			t.ColoredIcon("", t.Color.Green),
			desc,
			t.Dim(timing))
	}
	return err
}

func runSilent(t *terminal.Terminal, desc, cmdName string, args ...string) error {
	return runWithTimer(t, desc, func() error {
		c := exec.Command(cmdName, args...)
		return c.Run()
	})
}

func runWithOutput(t *terminal.Terminal, desc, cmdName string, args ...string) error {
	return runWithTimer(t, desc, func() error {
		c := exec.Command(cmdName, args...)
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		return c.Run()
	})
}
```

### 2. `internal/wizard/host.go` — Bubbletea TUI wizard

```go
package wizard

import (
	"fmt"
	"os"
	"strings"

	"github.com/charmbracelet/bubbletea"
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
	textCursor    int
	featureCursor int
	sshLine       int
	err           string
	done          bool
	genResult     string
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
	warnStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("#FBBF24"))
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
			m.genResult = "Host configuration generated."
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
		b.WriteString(m.renderTextInput("Host name", "Enter the hostname (e.g. prague, tokyo, nyc)", m.hostName, false))
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
		b.WriteString("\n  " + dimStyle.Render("Leave empty for default: " + m.userName))
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
		name := boldStyle.Render(featureDesc[f])
		b.WriteString(fmt.Sprintf("  %s%s %s\n", cursor, box, name))
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
```

---

## Files to Modify

### 3. `internal/commands/deploy.go`

Replace `RunE` body (lines 21-55):

```go
RunE: func(cmd *cobra.Command, args []string) error {
    if !a.RequireRepo() {
        return nil
    }
    t := a.Term
    root := a.Repo.Root
    host := args[0]

    fmt.Println()
    fmt.Println(t.Section("Deploy"))
    fmt.Println()
    fmt.Printf("  %s %s\n", t.Dim("Target:"), t.Code(host))
    fmt.Println()

    if !confirmAction(t, "Deploy to "+host+"?") {
        fmt.Println("  " + t.Dim("Cancelled"))
        fmt.Println()
        return nil
    }

    return runWithTimer(t, "Deploying to "+host, func() error {
        c := exec.Command("nixos-rebuild", "switch",
            "--flake", root+"#"+host,
            "--target-host", host,
        )
        c.Stdout = os.Stdout
        c.Stderr = os.Stderr
        return c.Run()
    })
},
```

Remove unused `os` import.

### 4. `internal/commands/rebuild.go`

Replace entire file content:

```go
package commands

import (
	"fmt"
	"os/exec"

	"github.com/spf13/cobra"
	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdRebuild(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "rebuild [host]",
		Short: "Run nixos-rebuild switch",
		Long: `Build and activate a new configuration on the target host.
If no host is specified, builds the current system.

Runs: sudo nixos-rebuild switch --flake .#<host>`,
		Args: cobra.MaximumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}
			t := a.Term
			root := a.Repo.Root

			host := ""
			if len(args) > 0 {
				host = args[0]
			}

			fmt.Println()
			fmt.Println(t.Section("Rebuild"))
			fmt.Println()

			rebuildArgs := []string{"nixos-rebuild", "switch", "--flake", root}
			if host != "" {
				rebuildArgs[len(rebuildArgs)-1] = root + "#" + host
			}

			label := "Rebuilding system"
			if host != "" {
				label += " (" + host + ")"
			}

			if !confirmAction(t, label+"?") {
				fmt.Println("  " + t.Dim("Cancelled"))
				fmt.Println()
				return nil
			}

			return runWithOutput(t, label, "sudo", rebuildArgs...)
		},
	}
}
```

### 5. `internal/commands/reconcile.go`

Replace `RunE` body (starting at line 19):

```go
RunE: func(cmd *cobra.Command, args []string) error {
    if !a.RequireRepo() {
        return nil
    }
    t := a.Term
    root := a.Repo.Root

    fmt.Println()
    fmt.Println(t.Section("Reconcile"))
    fmt.Println()

    if !confirmAction(t, "Reconcile (pull + rebuild)?") {
        fmt.Println("  " + t.Dim("Cancelled"))
        fmt.Println()
        return nil
    }

    if err := runSilent(t, "Pulling latest changes", "git", "-C", root, "pull", "--ff-only"); err != nil {
        fmt.Println()
        return nil
    }

    return runWithOutput(t, "Rebuilding system", "sudo", "nixos-rebuild", "switch", "--flake", root)
},
```

Remove unused `os/exec` import (no longer used directly since we use runSilent/runWithOutput).

### 6. `internal/commands/update.go`

Replace `RunE` body (starting at line 20):

```go
RunE: func(cmd *cobra.Command, args []string) error {
    if !a.RequireRepo() {
        return nil
    }
    t := a.Term
    root := a.Repo.Root

    fmt.Println()
    fmt.Println(t.Section("Update"))
    fmt.Println()

    if !confirmAction(t, "Update (pull + flake update)?") {
        fmt.Println("  " + t.Dim("Cancelled"))
        fmt.Println()
        return nil
    }

    if err := runWithOutput(t, "Pulling latest changes", "git", "-C", root, "pull", "--ff-only"); err != nil {
        fmt.Println()
        return nil
    }

    return runWithOutput(t, "Updating flake inputs", "nix", "flake", "update", "--option", "flake-dir", root)
},
```

Remove unused `os` import.

### 7. `internal/commands/status.go`

**Add imports**: `"os/exec"`, `"strings"`

**Replace Git section** (around line 40-42):
```go
fmt.Println(t.Section("Git"))
branch := getGitBranch(r.Root)
fmt.Println(t.KeyValue("Branch", branch))
fmt.Println(t.KeyValue("Status", t.Good("healthy")))
```

**Add helper function at end** (replace existing `joinHosts`):
```go
func getGitBranch(repoPath string) string {
    out, err := exec.Command("git", "-C", repoPath, "rev-parse", "--abbrev-ref", "HEAD").Output()
    if err != nil {
        return "unknown"
    }
    return strings.TrimSpace(string(out))
}

func joinHosts(hosts []string) string {
    switch len(hosts) {
    case 0:
        return ""
    case 1:
        return hosts[0]
    default:
        return strings.Join(hosts, ", ")
    }
}
```

### 8. `internal/commands/bootstrap_host.go`

**Add imports**:
```go
tea "github.com/charmbracelet/bubbletea"
"github.com/willisivali/nixos-infrastructure/internal/wizard"
"os"
```

**Replace `runInteractiveHostBootstrap`** (lines 192-195):
```go
func runInteractiveHostBootstrap(a *app.App) error {
    t := a.Term
    p := tea.NewProgram(wizard.NewHostWizard(t), tea.WithAltScreen())
    if _, err := p.Run(); err != nil {
        return err
    }
    return nil
}
```

**Replace `updateHostRegistry`** (lines 197-204):
```go
func updateHostRegistry(root string, spec template.HostSpec, force bool) error {
    registryPath := filepath.Join(root, "hosts", "hosts.nix")
    data, err := os.ReadFile(registryPath)
    if err != nil {
        return fmt.Errorf("read host registry: %w", err)
    }

    content := string(data)
    hostEntry := generateHostEntry(spec)

    // Insert before the final "}" that closes the attrset
    idx := strings.LastIndex(content, "}\n")
    if idx < 0 {
        return fmt.Errorf("could not find insertion point in hosts.nix")
    }

    newContent := content[:idx] + hostEntry + "\n" + content[idx:]
    return os.WriteFile(registryPath, []byte(newContent), 0644)
}

func generateHostEntry(spec template.HostSpec) string {
    var b strings.Builder
    b.WriteString(fmt.Sprintf("\n  %s = {\n", spec.HostName))
    b.WriteString(fmt.Sprintf("    hostName = \"%s\";\n", spec.HostName))
    b.WriteString(fmt.Sprintf("    userName = \"%s\";\n", spec.UserName))
    b.WriteString(fmt.Sprintf("    repoPath = \"%s\";\n", spec.RepoPath))
    b.WriteString("    tags = [ ")
    for _, t := range spec.Tags {
        b.WriteString(fmt.Sprintf("\"%s\" ", t))
    }
    b.WriteString("];\n")
    if spec.TailnetDomain != "" {
        b.WriteString(fmt.Sprintf("    tailnetDomain = \"%s\";\n", spec.TailnetDomain))
    } else {
        b.WriteString("    tailnetDomain = null;\n")
    }
    b.WriteString("    gitlabRunnerTags = [ ")
    for _, t := range spec.GitLabRunnerTags {
        b.WriteString(fmt.Sprintf("\"%s\" ", t))
    }
    b.WriteString("];\n")
    b.WriteString("    sshAuthorizedKeys = [\n")
    for _, k := range spec.SSHAuthorizedKeys {
        b.WriteString(fmt.Sprintf("      \"%s\";\n", k))
    }
    b.WriteString("    ];\n")
    b.WriteString(fmt.Sprintf("    sopsKeyPath = \"/home/%s/.config/sops/age/keys.txt\";\n", spec.UserName))
    b.WriteString("    features = {\n")
    for _, name := range []string{"secrets", "gitlabRunner", "bot", "tailscale", "tailscaleExitNode", "ssh"} {
        val := "false"
        if spec.Features[name] {
            val = "true"
        }
        b.WriteString(fmt.Sprintf("      %s = %s;\n", name, val))
    }
    b.WriteString("    };\n")
    b.WriteString("    config = {};\n")
    b.WriteString("  };")
    return b.String()
}
```
