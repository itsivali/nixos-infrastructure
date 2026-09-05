package security

import (
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

type ScanResult struct {
	Timestamp   time.Time  `json:"timestamp"`
	OverallPass bool       `json:"overall_pass"`
	Score       int        `json:"score"`
	MaxScore    int        `json:"max_score"`
	Categories  []Category `json:"categories"`
}

type Category struct {
	Name   string  `json:"name"`
	Pass   bool    `json:"pass"`
	Checks []Check `json:"checks"`
}

type Check struct {
	Name     string `json:"name"`
	Pass     bool   `json:"pass"`
	Message  string `json:"message"`
	Severity string `json:"severity"`
}

func RunFullScan() (*ScanResult, error) {
	result := &ScanResult{
		Timestamp: time.Now(),
		MaxScore:  100,
	}

	categories := []struct {
		name   string
		checks []func() Check
	}{
		{"firewall", firewallChecks()},
		{"kernel", kernelChecks()},
		{"ssh", sshChecks()},
		{"services", serviceChecks()},
		{"secrets", secretChecks()},
		{"filesystem", filesystemChecks()},
	}

	for _, cat := range categories {
		category := Category{Name: cat.name, Pass: true}
		for _, checkFn := range cat.checks {
			check := checkFn()
			category.Checks = append(category.Checks, check)
			if !check.Pass {
				category.Pass = false
			}
		}
		result.Categories = append(result.Categories, category)
	}

	passed := 0
	total := 0
	for _, cat := range result.Categories {
		for _, check := range cat.Checks {
			total++
			if check.Pass {
				passed++
			}
		}
	}

	result.Score = passed * 100 / total
	result.OverallPass = result.Score >= 80

	return result, nil
}

func firewallChecks() []func() Check {
	notRoot := os.Geteuid() != 0
	skipMsg := func(name string) Check {
		return Check{Name: name, Pass: true, Message: "skipped (requires root)", Severity: "high"}
	}
	return []func() Check{
		func() Check {
			out, err := exec.Command("nft", "list", "ruleset").CombinedOutput()
			if err != nil {
				if notRoot {
					return skipMsg("nftables")
				}
				return Check{Name: "nftables", Pass: false, Message: "nftables not available", Severity: "critical"}
			}
			hasDrop := strings.Contains(string(out), "policy drop")
			return Check{
				Name:     "nftables",
				Pass:     hasDrop,
				Message:  fmt.Sprintf("policy drop: %v", hasDrop),
				Severity: "critical",
			}
		},
		func() Check {
			out, err := exec.Command("nft", "list", "ruleset").CombinedOutput()
			if err != nil {
				if notRoot {
					return skipMsg("ssh-tailscale")
				}
				return Check{Name: "ssh-tailscale", Pass: false, Message: "cannot check", Severity: "high"}
			}
			re := regexp.MustCompile(`tcp dport 22.*iifname "tailscale0"`)
			hasSSHRestriction := re.MatchString(string(out))
			return Check{
				Name:     "ssh-tailscale",
				Pass:     hasSSHRestriction,
				Message:  fmt.Sprintf("SSH restricted to Tailscale: %v", hasSSHRestriction),
				Severity: "high",
			}
		},
	}
}

func kernelChecks() []func() Check {
	return []func() Check{
		func() Check {
			out, err := exec.Command("cat", "/proc/cmdline").CombinedOutput()
			if err != nil {
				return Check{Name: "slab_nomerge", Pass: false, Message: "cannot read", Severity: "medium"}
			}
			hasFlag := strings.Contains(string(out), "slab_nomerge")
			return Check{
				Name:     "slab_nomerge",
				Pass:     hasFlag,
				Message:  fmt.Sprintf("slab_nomerge: %v", hasFlag),
				Severity: "medium",
			}
		},
		func() Check {
			out, err := exec.Command("cat", "/proc/cmdline").CombinedOutput()
			if err != nil {
				return Check{Name: "init_on_alloc", Pass: false, Message: "cannot read", Severity: "medium"}
			}
			hasFlag := strings.Contains(string(out), "init_on_alloc=1")
			return Check{
				Name:     "init_on_alloc",
				Pass:     hasFlag,
				Message:  fmt.Sprintf("init_on_alloc=1: %v", hasFlag),
				Severity: "medium",
			}
		},
		func() Check {
			out, err := exec.Command("cat", "/proc/sys/kernel/kptr_restrict").CombinedOutput()
			if err != nil {
				return Check{Name: "kptr_restrict", Pass: false, Message: "cannot read", Severity: "medium"}
			}
			val := strings.TrimSpace(string(out))
			return Check{
				Name:     "kptr_restrict",
				Pass:     val == "2",
				Message:  fmt.Sprintf("kptr_restrict=%s", val),
				Severity: "medium",
			}
		},
		func() Check {
			out, err := exec.Command("cat", "/proc/sys/kernel/dmesg_restrict").CombinedOutput()
			if err != nil {
				return Check{Name: "dmesg_restrict", Pass: false, Message: "cannot read", Severity: "low"}
			}
			val := strings.TrimSpace(string(out))
			return Check{
				Name:     "dmesg_restrict",
				Pass:     val == "1",
				Message:  fmt.Sprintf("dmesg_restrict=%s", val),
				Severity: "low",
			}
		},
		func() Check {
			out, err := exec.Command("cat", "/proc/sys/fs/suid_dumpable").CombinedOutput()
			if err != nil {
				return Check{Name: "coredump", Pass: false, Message: "cannot read", Severity: "medium"}
			}
			val := strings.TrimSpace(string(out))
			return Check{
				Name:     "coredump",
				Pass:     val == "0",
				Message:  fmt.Sprintf("suid_dumpable=%s", val),
				Severity: "medium",
			}
		},
	}
}

func sshEffectiveConfig() (string, error) {
	out, err := exec.Command("sshd", "-T").CombinedOutput()
	if err == nil {
		return string(out), nil
	}
	// sshd -T fails for non-root users (cannot read root-owned host keys).
	// Fall back to parsing the on-disk config.
	raw, readErr := os.ReadFile("/etc/ssh/sshd_config")
	if readErr != nil {
		return "", fmt.Errorf("sshd -T failed: %v; read sshd_config: %w", err, readErr)
	}
	return string(raw), nil
}

func sshChecks() []func() Check {
	return []func() Check{
		func() Check {
			config, err := sshEffectiveConfig()
			if err != nil {
				return Check{Name: "password-auth", Pass: false, Message: err.Error(), Severity: "high"}
			}
			re := regexp.MustCompile(`(?mi)^passwordauthentication\s+(\w+)`)
			matches := re.FindStringSubmatch(config)
			if len(matches) < 2 {
				return Check{Name: "password-auth", Pass: false, Message: "not found", Severity: "high"}
			}
			disabled := matches[1] == "no"
			return Check{
				Name:     "password-auth",
				Pass:     disabled,
				Message:  fmt.Sprintf("password auth: %s", matches[1]),
				Severity: "high",
			}
		},
		func() Check {
			config, err := sshEffectiveConfig()
			if err != nil {
				return Check{Name: "permit-root", Pass: false, Message: err.Error(), Severity: "high"}
			}
			re := regexp.MustCompile(`(?mi)^permitrootlogin\s+(\w+)`)
			matches := re.FindStringSubmatch(config)
			if len(matches) < 2 {
				return Check{Name: "permit-root", Pass: true, Message: "not found (default no)", Severity: "high"}
			}
			disabled := matches[1] == "no"
			return Check{
				Name:     "permit-root",
				Pass:     disabled,
				Message:  fmt.Sprintf("permit root: %s", matches[1]),
				Severity: "high",
			}
		},
	}
}

func serviceChecks() []func() Check {
	services := []struct {
		name     string
		service  string
		severity string
	}{
		{"sshd", "sshd", "high"},
		{"tailscale", "tailscaled", "medium"},
		{"fail2ban", "fail2ban", "medium"},
		{"networkmanager", "NetworkManager", "medium"},
	}

	var checks []func() Check
	for _, svc := range services {
		s := svc
		checks = append(checks, func() Check {
			out, _ := exec.Command("systemctl", "is-active", s.service).CombinedOutput()
			active := strings.TrimSpace(string(out)) == "active"
			return Check{
				Name:     s.name,
				Pass:     active,
				Message:  fmt.Sprintf("service %s: %s", s.service, strings.TrimSpace(string(out))),
				Severity: s.severity,
			}
		})
	}
	return checks
}

// runtimeSecretsMounted reports whether the runtime secrets mount exists.
// Existence (via os.Stat) is the signal — ls output is not used so a missing
// mount cannot masquerade as present via stderr text ending up in stdout.
func runtimeSecretsMounted(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func secretChecks() []func() Check {
	return []func() Check{
		func() Check {
			_, err := exec.Command("ls", "-la", "/home/ivali/.config/sops/age/keys.txt").CombinedOutput()
			exists := err == nil
			return Check{
				Name:     "sops-key",
				Pass:     exists,
				Message:  fmt.Sprintf("SOPS age key: %v", exists),
				Severity: "high",
			}
		},
		func() Check {
			return Check{
				Name:     "runtime-secrets",
				Pass:     runtimeSecretsMounted("/run/secrets"),
				Message:  fmt.Sprintf("runtime secrets mounted: %v", runtimeSecretsMounted("/run/secrets")),
				Severity: "medium",
			}
		},
	}
}

func filesystemChecks() []func() Check {
	return []func() Check{
		func() Check {
			out, err := exec.Command("cat", "/proc/sys/fs/protected_hardlinks").CombinedOutput()
			if err != nil {
				return Check{Name: "protected-hardlinks", Pass: false, Message: "cannot read", Severity: "low"}
			}
			val := strings.TrimSpace(string(out))
			return Check{
				Name:     "protected-hardlinks",
				Pass:     val == "1" || val == "2",
				Message:  fmt.Sprintf("protected_hardlinks=%s", val),
				Severity: "low",
			}
		},
		func() Check {
			out, err := exec.Command("cat", "/proc/sys/fs/protected_symlinks").CombinedOutput()
			if err != nil {
				return Check{Name: "protected-symlinks", Pass: false, Message: "cannot read", Severity: "low"}
			}
			val := strings.TrimSpace(string(out))
			return Check{
				Name:     "protected-symlinks",
				Pass:     val == "1" || val == "2",
				Message:  fmt.Sprintf("protected_symlinks=%s", val),
				Severity: "low",
			}
		},
	}
}

func FormatResult(result *ScanResult) string {
	var sb strings.Builder

	status := "PASS"
	if !result.OverallPass {
		status = "FAIL"
	}
	sb.WriteString(fmt.Sprintf("Security Scan: %s (Score: %d/%d)\n\n", status, result.Score, result.MaxScore))

	for _, cat := range result.Categories {
		icon := "✓"
		if !cat.Pass {
			icon = "✗"
		}
		sb.WriteString(fmt.Sprintf("%s %s\n", icon, cat.Name))

		for _, check := range cat.Checks {
			checkIcon := "  ✓"
			if !check.Pass {
				checkIcon = "  ✗"
			}
			sb.WriteString(fmt.Sprintf("%s %s: %s\n", checkIcon, check.Name, check.Message))
		}
		sb.WriteString("\n")
	}

	return sb.String()
}

func FormatJSON(result *ScanResult) string {
	var sb strings.Builder
	sb.WriteString("{\n")
	sb.WriteString(fmt.Sprintf(`  "timestamp": "%s",`, result.Timestamp.Format(time.RFC3339)))
	sb.WriteString(fmt.Sprintf(`  "overall_pass": %v,`, result.OverallPass))
	sb.WriteString(fmt.Sprintf(`  "score": %d,`, result.Score))
	sb.WriteString(fmt.Sprintf(`  "max_score": %d,`, result.MaxScore))
	sb.WriteString(`  "categories": [`)
	for i, cat := range result.Categories {
		if i > 0 {
			sb.WriteString(",")
		}
		sb.WriteString(fmt.Sprintf(`{"name":"%s","pass":%v,"checks":[`, cat.Name, cat.Pass))
		for j, check := range cat.Checks {
			if j > 0 {
				sb.WriteString(",")
			}
			sb.WriteString(fmt.Sprintf(`{"name":"%s","pass":%v,"message":"%s","severity":"%s"}`,
				check.Name, check.Pass, check.Message, check.Severity))
		}
		sb.WriteString("]}")
	}
	sb.WriteString("]\n}")
	return sb.String()
}

func ScoreFromResult(result *ScanResult) string {
	score := result.Score
	switch {
	case score >= 90:
		return fmt.Sprintf("Excellent (%d%%)", score)
	case score >= 80:
		return fmt.Sprintf("Good (%d%%)", score)
	case score >= 70:
		return fmt.Sprintf("Fair (%d%%)", score)
	case score >= 60:
		return fmt.Sprintf("Poor (%d%%)", score)
	default:
		return fmt.Sprintf("Critical (%d%%)", score)
	}
}

type CheckItem struct {
	Label  string
	Status int
	Detail string
}

const (
	StatusPass = 0
	StatusWarn = 1
	StatusFail = 2
)

func ScanResultToCheckItems(result *ScanResult) []CheckItem {
	var items []CheckItem
	for _, cat := range result.Categories {
		for _, check := range cat.Checks {
			status := StatusPass
			if !check.Pass {
				if check.Severity == "critical" || check.Severity == "high" {
					status = StatusFail
				} else {
					status = StatusWarn
				}
			}
			items = append(items, CheckItem{
				Label:  fmt.Sprintf("[%s] %s", cat.Name, check.Name),
				Status: status,
				Detail: check.Message,
			})
		}
	}
	return items
}

func ScanResultToCategoryItems(result *ScanResult) [][]CheckItem {
	var categories [][]CheckItem
	for _, cat := range result.Categories {
		var items []CheckItem
		for _, check := range cat.Checks {
			status := StatusPass
			if !check.Pass {
				if check.Severity == "critical" || check.Severity == "high" {
					status = StatusFail
				} else {
					status = StatusWarn
				}
			}
			items = append(items, CheckItem{
				Label:  check.Name,
				Status: status,
				Detail: check.Message,
			})
		}
		categories = append(categories, items)
	}
	return categories
}
