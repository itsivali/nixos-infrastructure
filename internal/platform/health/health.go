package health

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/state"
)

type CheckResult struct {
	Name    string
	State   state.State
	Message string
	Detail  string
}

type CheckFunc func() CheckResult

var (
	DiskWarnThreshold   = 80
	DiskCritThreshold   = 90
	MemoryWarnThreshold = 85
	MemoryCritThreshold = 95
	CPUWarnRatio        = 1.5
	CPUCritRatio        = 2.0
)

var DefaultServices = []string{
	"sshd",
	"NetworkManager",
	"tailscaled",
	"systemd-timesyncd",
}

func CheckDisk() CheckResult {
	out, err := exec.Command("sh", "-c", "df -h / | tail -1 | awk '{print $5}' | tr -d '%'").CombinedOutput()
	if err != nil {
		return CheckResult{Name: "disk", State: state.StateWarning, Message: "unable to check disk", Detail: err.Error()}
	}

	percent := strings.TrimSpace(string(out))
	used, _ := strconv.Atoi(percent)

	if used >= DiskCritThreshold {
		return CheckResult{Name: "disk", State: state.StateDegraded, Message: fmt.Sprintf("disk usage critical: %s%%", percent)}
	}
	if used >= DiskWarnThreshold {
		return CheckResult{Name: "disk", State: state.StateWarning, Message: fmt.Sprintf("disk usage high: %s%%", percent)}
	}
	return CheckResult{Name: "disk", State: state.StateHealthy, Message: fmt.Sprintf("disk usage normal: %s%%", percent)}
}

func CheckDiskDetailed() CheckResult {
	mounts := []string{"/", "/nix/store", "/home"}
	var details []string
	var worst state.State

	for _, m := range mounts {
		if _, err := os.Stat(m); err != nil {
			continue
		}
		out, err := exec.Command("df", "-h", m).Output()
		if err != nil {
			continue
		}
		lines := strings.Split(strings.TrimSpace(string(out)), "\n")
		if len(lines) < 2 {
			continue
		}
		fields := strings.Fields(lines[len(lines)-1])
		if len(fields) < 5 {
			continue
		}
		pct := strings.TrimSuffix(fields[4], "%")
		val, _ := strconv.Atoi(pct)
		usage := fmt.Sprintf("%s: %s/%s (%s%%)", m, fields[2], fields[3], pct)
		if val >= DiskCritThreshold {
			details = append(details, "✗ "+usage)
			worst = state.StateDegraded
		} else if val >= DiskWarnThreshold {
			details = append(details, "⚠ "+usage)
			if worst != state.StateDegraded {
				worst = state.StateWarning
			}
		} else {
			details = append(details, usage)
			if worst == state.StateUnknown {
				worst = state.StateHealthy
			}
		}
	}

	if worst == state.StateUnknown {
		worst = state.StateHealthy
	}
	detail := strings.Join(details, ", ")
	if detail == "" {
		detail = "unable to read"
		worst = state.StateWarning
	}
	return CheckResult{Name: "disk", State: worst, Message: detail, Detail: detail}
}

func CheckMemory() CheckResult {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return CheckResult{Name: "memory", State: state.StateWarning, Message: "unable to read /proc/meminfo"}
	}

	var total, avail uint64
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "MemTotal:") {
			_, _ = fmt.Sscanf(line, "MemTotal: %d", &total)
		}
		if strings.HasPrefix(line, "MemAvailable:") {
			_, _ = fmt.Sscanf(line, "MemAvailable: %d", &avail)
		}
	}

	if total == 0 {
		return CheckResult{Name: "memory", State: state.StateWarning, Message: "unable to parse meminfo"}
	}

	used := total - avail
	pct := used * 100 / total
	usedGB := float64(used) / 1024 / 1024
	totalGB := float64(total) / 1024 / 1024
	detail := fmt.Sprintf("%.1fG/%.1fG (%d%%)", usedGB, totalGB, pct)

	if int(pct) >= MemoryCritThreshold {
		return CheckResult{Name: "memory", State: state.StateDegraded, Message: fmt.Sprintf("memory usage critical: %d%%", pct), Detail: detail}
	}
	if int(pct) >= MemoryWarnThreshold {
		return CheckResult{Name: "memory", State: state.StateWarning, Message: fmt.Sprintf("memory usage high: %d%%", pct), Detail: detail}
	}
	return CheckResult{Name: "memory", State: state.StateHealthy, Message: fmt.Sprintf("memory usage normal: %d%%", pct), Detail: detail}
}

func CheckCPULoad() CheckResult {
	data, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return CheckResult{Name: "cpu", State: state.StateWarning, Message: "unable to read /proc/loadavg"}
	}

	parts := strings.Fields(string(data))
	if len(parts) < 1 {
		return CheckResult{Name: "cpu", State: state.StateWarning, Message: "unable to parse loadavg"}
	}

	cpus := runtime.NumCPU()
	load1, _ := strconv.ParseFloat(parts[0], 64)
	ratio := load1 / float64(cpus)
	detail := fmt.Sprintf("%s (%.0f%% of %d cores)", parts[0], ratio*100, cpus)

	if ratio > CPUCritRatio {
		return CheckResult{Name: "cpu", State: state.StateDegraded, Message: fmt.Sprintf("load critical: %s (%.1fx cores)", parts[0], ratio), Detail: detail}
	}
	if ratio > CPUWarnRatio {
		return CheckResult{Name: "cpu", State: state.StateWarning, Message: fmt.Sprintf("load high: %s (%.1fx cores)", parts[0], ratio), Detail: detail}
	}
	return CheckResult{Name: "cpu", State: state.StateHealthy, Message: fmt.Sprintf("load normal: %s", parts[0]), Detail: detail}
}

func CheckUptime() CheckResult {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return CheckResult{Name: "uptime", State: state.StateHealthy, Message: "unknown"}
	}

	parts := strings.Fields(string(data))
	if len(parts) == 0 {
		return CheckResult{Name: "uptime", State: state.StateHealthy, Message: "unknown"}
	}

	secs, err := strconv.ParseFloat(parts[0], 64)
	if err != nil {
		return CheckResult{Name: "uptime", State: state.StateHealthy, Message: "unknown"}
	}

	d := int(secs) / 86400
	h := int(secs) % 86400 / 3600
	m := int(secs) % 3600 / 60

	var detail string
	if d > 0 {
		detail = fmt.Sprintf("%dd %dh %dm", d, h, m)
	} else if h > 0 {
		detail = fmt.Sprintf("%dh %dm", h, m)
	} else {
		detail = fmt.Sprintf("%dm", m)
	}

	return CheckResult{Name: "uptime", State: state.StateHealthy, Message: detail, Detail: detail}
}

func CheckService(name string) CheckResult {
	out, err := exec.Command("systemctl", "is-active", name).CombinedOutput()
	status := strings.TrimSpace(string(out))

	if err != nil || status != "active" {
		return CheckResult{Name: name, State: state.StateDegraded, Message: fmt.Sprintf("service %s is %s", name, status)}
	}
	return CheckResult{Name: name, State: state.StateHealthy, Message: fmt.Sprintf("service %s is active", name)}
}

func CheckServices(services []string) CheckResult {
	if services == nil {
		services = DefaultServices
	}
	var failing, unchecked []string
	for _, svc := range services {
		r := CheckService(svc)
		if r.State == state.StateDegraded {
			failing = append(failing, svc)
		} else if r.State == state.StateWarning {
			unchecked = append(unchecked, svc)
		}
	}

	if len(failing) > 0 {
		return CheckResult{Name: "services", State: state.StateDegraded, Message: "inactive: " + strings.Join(failing, ", ")}
	}
	if len(unchecked) > 0 {
		return CheckResult{Name: "services", State: state.StateWarning, Message: "unchecked: " + strings.Join(unchecked, ", ")}
	}
	return CheckResult{Name: "services", State: state.StateHealthy, Message: "all active"}
}

func CheckNixStore() CheckResult {
	if _, err := exec.LookPath("nix"); err != nil {
		return CheckResult{Name: "nix-store", State: state.StateHealthy, Message: "nix not installed"}
	}
	out, err := exec.Command("nix", "store", "info").CombinedOutput()
	if err != nil {
		return CheckResult{Name: "nix-store", State: state.StateWarning, Message: "unreachable"}
	}
	return CheckResult{Name: "nix-store", State: state.StateHealthy, Message: strings.TrimSpace(string(out))}
}

func CheckTailscale() CheckResult {
	if _, err := exec.LookPath("tailscale"); err != nil {
		return CheckResult{Name: "tailscale", State: state.StateHealthy, Message: "not installed"}
	}
	if _, err := exec.Command("tailscale", "status", "--json").Output(); err != nil {
		return CheckResult{Name: "tailscale", State: state.StateWarning, Message: "not connected"}
	}
	return CheckResult{Name: "tailscale", State: state.StateHealthy, Message: "connected"}
}

func CheckNixFormatting(root string) CheckResult {
	hasUncommitted, _ := exec.Command("git", "-C", root, "diff", "--quiet", "--", "*.nix").Output()
	hasStaged, _ := exec.Command("git", "-C", root, "diff", "--cached", "--quiet", "--", "*.nix").Output()

	if hasUncommitted != nil || hasStaged != nil {
		return CheckResult{Name: "formatting", State: state.StateWarning, Message: "skipped (uncommitted .nix changes present)"}
	}

	nixFmt := exec.Command("nix", "fmt")
	nixFmt.Dir = root
	_ = nixFmt.Run()

	out, _ := exec.Command("git", "-C", root, "diff", "--stat", "--", "*.nix").Output()
	if len(out) > 0 {
		_ = exec.Command("git", "-C", root, "checkout", "--", "*.nix").Run()
		return CheckResult{Name: "formatting", State: state.StateDegraded, Message: strings.TrimSpace(string(out))}
	}
	return CheckResult{Name: "formatting", State: state.StateHealthy, Message: "all .nix files formatted"}
}

func RunAllSystemChecks() []CheckResult {
	return []CheckResult{
		CheckDisk(),
		CheckMemory(),
		CheckCPULoad(),
		CheckUptime(),
		CheckServices(nil),
		CheckNixStore(),
		CheckTailscale(),
	}
}
