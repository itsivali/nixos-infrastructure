package commands

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"

	"github.com/willisivali/nixos-infrastructure/internal/terminal"
)

type healthFunc func() terminal.CheckItem

func systemHealthChecks() []terminal.CheckItem {
	checks := []healthFunc{
		checkDiskUsage,
		checkMemory,
		checkCPULoad,
		checkSystemUptime,
		checkServices,
		checkNixStore,
		checkTailscale,
	}

	items := make([]terminal.CheckItem, 0, len(checks))
	for _, fn := range checks {
		items = append(items, fn())
	}
	return items
}

func checkDiskUsage() terminal.CheckItem {
	mounts := []string{"/", "/nix/store", "/home"}
	var details []string
	var hasWarn, hasFail bool

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
		val, err := strconv.Atoi(pct)
		if err != nil {
			continue
		}
		usage := fmt.Sprintf("%s: %s/%s (%s%%)", m, fields[2], fields[3], pct)
		if val >= 95 {
			details = append(details, " "+usage)
			hasFail = true
		} else if val >= 80 {
			details = append(details, " "+usage)
			hasWarn = true
		} else {
			details = append(details, usage)
		}
	}

	status := terminal.StatusPass
	if hasFail {
		status = terminal.StatusFail
	} else if hasWarn {
		status = terminal.StatusWarn
	}

	detail := strings.Join(details, ", ")
	if detail == "" {
		detail = "unable to read"
		status = terminal.StatusWarn
	}

	return terminal.CheckItem{Label: "Disk Usage", Status: status, Detail: detail}
}

func checkMemory() terminal.CheckItem {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return terminal.CheckItem{Label: "Memory", Status: terminal.StatusWarn, Detail: "unable to read /proc/meminfo"}
	}

	var total, avail uint64
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "MemTotal:") {
			fmt.Sscanf(line, "MemTotal: %d", &total)
		}
		if strings.HasPrefix(line, "MemAvailable:") {
			fmt.Sscanf(line, "MemAvailable: %d", &avail)
		}
	}

	if total == 0 {
		return terminal.CheckItem{Label: "Memory", Status: terminal.StatusWarn, Detail: "unable to parse meminfo"}
	}

	used := total - avail
	pct := used * 100 / total

	usedGB := float64(used) / 1024 / 1024
	totalGB := float64(total) / 1024 / 1024
	detail := fmt.Sprintf("%.1fG/%.1fG (%d%%)", usedGB, totalGB, pct)

	status := terminal.StatusPass
	if pct >= 95 {
		status = terminal.StatusFail
	} else if pct >= 85 {
		status = terminal.StatusWarn
	}

	return terminal.CheckItem{Label: "Memory", Status: status, Detail: detail}
}

func checkCPULoad() terminal.CheckItem {
	data, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return terminal.CheckItem{Label: "CPU Load", Status: terminal.StatusWarn, Detail: "unable to read /proc/loadavg"}
	}

	parts := strings.Fields(string(data))
	if len(parts) < 3 {
		return terminal.CheckItem{Label: "CPU Load", Status: terminal.StatusWarn, Detail: "unable to parse loadavg"}
	}

	cpus := runtime.NumCPU()
	load1, _ := strconv.ParseFloat(parts[0], 64)

	detail := fmt.Sprintf("%s (%.0f%% of %d cores)", parts[0], load1/float64(cpus)*100, cpus)

	status := terminal.StatusPass
	if load1 > float64(cpus)*2 {
		status = terminal.StatusFail
	} else if load1 > float64(cpus) {
		status = terminal.StatusWarn
	}

	return terminal.CheckItem{Label: "CPU Load", Status: status, Detail: detail}
}

func checkSystemUptime() terminal.CheckItem {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return terminal.CheckItem{Label: "Uptime", Status: terminal.StatusPass, Detail: "unknown"}
	}

	parts := strings.Fields(string(data))
	if len(parts) == 0 {
		return terminal.CheckItem{Label: "Uptime", Status: terminal.StatusPass, Detail: "unknown"}
	}

	secs, err := strconv.ParseFloat(parts[0], 64)
	if err != nil {
		return terminal.CheckItem{Label: "Uptime", Status: terminal.StatusPass, Detail: "unknown"}
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

	return terminal.CheckItem{Label: "Uptime", Status: terminal.StatusPass, Detail: detail}
}

var keyServices = []string{
	"tailscaled",
	"NetworkManager",
	"systemd-timesyncd",
}

func checkServices() terminal.CheckItem {
	var failing []string
	var unknown []string
	for _, svc := range keyServices {
		out, err := exec.Command("systemctl", "is-active", svc).Output()
		if err != nil {
			unknown = append(unknown, svc)
			continue
		}
		status := strings.TrimSpace(string(out))
		if status != "active" {
			failing = append(failing, svc)
		}
	}

	status := terminal.StatusPass
	var detail string
	if len(failing) > 0 {
		status = terminal.StatusFail
		detail = "inactive: " + strings.Join(failing, ", ")
	} else if len(unknown) > 0 {
		status = terminal.StatusWarn
		detail = "unchecked: " + strings.Join(unknown, ", ")
	} else {
		detail = "all active"
	}

	return terminal.CheckItem{Label: "Services", Status: status, Detail: detail}
}

func checkNixStore() terminal.CheckItem {
	if _, err := exec.LookPath("nix"); err != nil {
		return terminal.CheckItem{Label: "Nix Store", Status: terminal.StatusPass, Detail: "nix not installed"}
	}

	out, err := exec.Command("nix", "store", "check").CombinedOutput()
	if err != nil {
		return terminal.CheckItem{Label: "Nix Store", Status: terminal.StatusWarn, Detail: strings.TrimSpace(string(out))}
	}

	detail := strings.TrimSpace(string(out))
	if detail == "" {
		detail = "integrity verified"
	}

	return terminal.CheckItem{Label: "Nix Store", Status: terminal.StatusPass, Detail: detail}
}

func checkTailscale() terminal.CheckItem {
	if _, err := exec.LookPath("tailscale"); err != nil {
		return terminal.CheckItem{Label: "Tailscale", Status: terminal.StatusPass, Detail: "not installed"}
	}

	if _, err := exec.Command("tailscale", "status", "--json").Output(); err != nil {
		return terminal.CheckItem{Label: "Tailscale", Status: terminal.StatusWarn, Detail: "not connected"}
	}

	return terminal.CheckItem{Label: "Tailscale", Status: terminal.StatusPass, Detail: "connected"}
}
