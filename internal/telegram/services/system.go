package services

import (
	"fmt"
	"strings"
)

// SystemService provides system information queries.
type SystemService struct {
	runner *Runner
}

// NewSystemService creates a new SystemService.
func NewSystemService(runner *Runner) *SystemService {
	return &SystemService{runner: runner}
}

// Uptime returns the system uptime string.
func (s *SystemService) Uptime() string {
	return s.runner.Run("uptime -p 2>/dev/null || uptime", 5)
}

// Memory returns parsed memory information.
func (s *SystemService) Memory() (memLine, swapLine, raw string) {
	raw = s.runner.Run("free -h", 5)
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", "", raw
	}

	for _, row := range strings.Split(raw, "\n") {
		fields := strings.Fields(row)
		if len(fields) < 2 {
			continue
		}
		switch fields[0] {
		case "Mem:":
			memLine = fmt.Sprintf("*Total:* `%s`  *Used:* `%s`  *Free:* `%s`  *Avail:* `%s`",
				fields[1], fields[2], fields[3], fields[6])
		case "Swap:":
			swapLine = fmt.Sprintf("*Swap Total:* `%s`  *Used:* `%s`  *Free:* `%s`",
				fields[1], fields[2], fields[3])
		}
	}
	return memLine, swapLine, raw
}

// DiskUsage returns root disk usage.
func (s *SystemService) DiskUsage() string {
	return s.runner.Run("df -h / | awk 'NR==2{printf \"%s used / %s (%s)\", $3, $2, $5}'", 5)
}

// DiskFull returns full disk info for / and /boot.
func (s *SystemService) DiskFull() string {
	return s.runner.Run("df -h / /boot 2>/dev/null", 10)
}

// LoadAvg returns the system load averages.
func (s *SystemService) LoadAvg() string {
	return s.runner.Run("cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}'", 5)
}

// CPUCores returns the number of CPU cores.
func (s *SystemService) CPUCores() string {
	return s.runner.Run("nproc 2>/dev/null || echo unknown", 5)
}

// CPUModel returns the CPU model name.
func (s *SystemService) CPUModel() string {
	return s.runner.Run("grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs", 5)
}

// Processes returns top processes by CPU usage.
func (s *SystemService) Processes() string {
	output := s.runner.Run("ps aux --sort=-%cpu | head -11", 5)
	if output == "" {
		output = s.runner.Run("ps aux | head -11", 5)
	}
	return output
}

// TopMetrics returns a combined system metrics view.
func (s *SystemService) TopMetrics() (uptime, memory, disk string) {
	uptime = s.runner.Run("uptime", 5)
	memory = s.runner.Run("free -h | head -2", 5)
	disk = s.runner.Run("df -h / | tail -1", 5)
	return
}

// Journal returns recent system journal entries.
func (s *SystemService) Journal() string {
	return s.runner.Run("journalctl -u ivali-bot -n 20 --no-pager 2>/dev/null || journalctl -n 20 --no-pager", 10)
}

// Notify sends a desktop notification.
func (s *SystemService) Notify(message string) string {
	s.runner.Run(fmt.Sprintf("notify-send 'Bot' %s", QuoteSh(message)), 5)
	return "Notification sent"
}

// ServiceStatus returns the active state of a systemd service.
func (s *SystemService) ServiceStatus(name string) string {
	return strings.TrimSpace(s.runner.Run(
		fmt.Sprintf("systemctl is-active %s 2>/dev/null || echo inactive", name), 5))
}

// FailedUnits returns the count of failed systemd units.
func (s *SystemService) FailedUnits() string {
	return strings.TrimSpace(s.runner.Run(
		"systemctl list-units --state=failed --no-legend 2>/dev/null | wc -l", 5))
}

// Hostname returns the system hostname.
func (s *SystemService) Hostname() string {
	return strings.TrimSpace(s.runner.Run("hostname", 5))
}
