package inventory

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"time"
)

type Inventory struct {
	Hostname    string
	OS          string
	Kernel      string
	Uptime      time.Duration
	CPU         CPUInfo
	GPU         []GPUInfo
	Memory      MemoryInfo
	Storage     []DiskInfo
	Roles       []string
	Desktop     string
	Services    []ServiceInfo
	Network     NetworkInfo
	Firewall    FirewallInfo
	Tailscale   TailscaleInfo
	Bootloader  string
	Encryption  EncryptionInfo
	GitRevision string
	FlakeInputs int
	Generations int
	Plugins     int
	Modules     ModuleCount
}

type CPUInfo struct {
	Model   string
	Cores   int
	Threads int
	Load1   float64
	Load5   float64
	Load15  float64
}

type GPUInfo struct {
	Vendor string
	Model  string
	Driver string
}

type MemoryInfo struct {
	TotalGB     float64
	AvailableGB float64
	UsedGB      float64
	UsedPercent int
}

type DiskInfo struct {
	MountPoint  string
	TotalGB     float64
	UsedGB      float64
	AvailGB     float64
	UsedPercent int
	FSType      string
}

type ServiceInfo struct {
	Name   string
	Active bool
	State  string
	Uptime string
}

type NetworkInfo struct {
	Hostname    string
	IPAddresses []string
	DNSServers  []string
}

type FirewallInfo struct {
	Enabled bool
	Rules   int
}

type TailscaleInfo struct {
	Installed bool
	Connected bool
	IP        string
	Hostname  string
}

type EncryptionInfo struct {
	LUKS bool
	FDE  bool
	SOPS bool
}

type ModuleCount struct {
	NixOS int
	HomeM int
	Total int
}

func Collect() *Inventory {
	inv := &Inventory{
		Hostname:   collectHostname(),
		OS:         collectOS(),
		Kernel:     collectKernel(),
		Uptime:     collectUptime(),
		CPU:        collectCPU(),
		GPU:        collectGPU(),
		Memory:     collectMemory(),
		Storage:    collectStorage(),
		Network:    collectNetwork(),
		Firewall:   collectFirewall(),
		Tailscale:  collectTailscale(),
		Bootloader: collectBootloader(),
		Encryption: collectEncryption(),
	}
	return inv
}

func collectHostname() string {
	out, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return out
}

func collectOS() string {
	out, err := exec.Command("nixos-version").Output()
	if err != nil {
		return "unknown"
	}
	return strings.TrimSpace(string(out))
}

func collectKernel() string {
	out, err := exec.Command("uname", "-r").Output()
	if err != nil {
		return "unknown"
	}
	return strings.TrimSpace(string(out))
}

func collectUptime() time.Duration {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return 0
	}
	parts := strings.Fields(string(data))
	if len(parts) == 0 {
		return 0
	}
	secs, err := strconv.ParseFloat(parts[0], 64)
	if err != nil {
		return 0
	}
	return time.Duration(secs) * time.Second
}

func collectCPU() CPUInfo {
	info := CPUInfo{Cores: runtime.NumCPU()}

	data, err := os.ReadFile("/proc/cpuinfo")
	if err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "model name") {
				parts := strings.SplitN(line, ":", 2)
				if len(parts) == 2 {
					info.Model = strings.TrimSpace(parts[1])
					break
				}
			}
		}
	}

	data, err = os.ReadFile("/proc/loadavg")
	if err == nil {
		parts := strings.Fields(string(data))
		if len(parts) >= 3 {
			info.Load1, _ = strconv.ParseFloat(parts[0], 64)
			info.Load5, _ = strconv.ParseFloat(parts[1], 64)
			info.Load15, _ = strconv.ParseFloat(parts[2], 64)
		}
	}

	out, err := exec.Command("nproc", "--all").Output()
	if err == nil {
		if n, err := strconv.Atoi(strings.TrimSpace(string(out))); err == nil {
			info.Threads = n
		}
	}

	return info
}

func collectGPU() []GPUInfo {
	out, err := exec.Command("sh", "-c", "lspci 2>/dev/null | grep -iE 'vga|3d|display'").Output()
	if err != nil {
		return nil
	}

	var gpus []GPUInfo
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) == 2 {
			gpu := GPUInfo{Model: strings.TrimSpace(parts[1])}
			if strings.Contains(strings.ToLower(gpu.Model), "amd") {
				gpu.Vendor = "AMD"
			} else if strings.Contains(strings.ToLower(gpu.Model), "nvidia") {
				gpu.Vendor = "NVIDIA"
			} else if strings.Contains(strings.ToLower(gpu.Model), "intel") {
				gpu.Vendor = "Intel"
			}
			gpus = append(gpus, gpu)
		}
	}
	return gpus
}

func collectMemory() MemoryInfo {
	var info MemoryInfo
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return info
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

	if total > 0 {
		info.TotalGB = float64(total) / 1024 / 1024
		info.AvailableGB = float64(avail) / 1024 / 1024
		info.UsedGB = info.TotalGB - info.AvailableGB
		info.UsedPercent = int((total - avail) * 100 / total)
	}
	return info
}

func collectStorage() []DiskInfo {
	out, err := exec.Command("df", "-B1", "--exclude-type=tmpfs", "--exclude-type=devtmpfs", "--exclude-type=overlay").Output()
	if err != nil {
		return nil
	}

	var disks []DiskInfo
	lines := strings.Split(string(out), "\n")
	for _, line := range lines[1:] {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 6 {
			continue
		}
		skip := false
		for _, s := range []string{"/run", "/proc", "/sys", "/dev", "/snap", "/var/lib/docker"} {
			if fields[5] == s || strings.HasPrefix(fields[5], s+"/") {
				skip = true
				break
			}
		}
		if skip {
			continue
		}

		total, _ := strconv.ParseUint(fields[1], 10, 64)
		used, _ := strconv.ParseUint(fields[2], 10, 64)
		avail, _ := strconv.ParseUint(fields[3], 10, 64)

		pct := 0
		if total > 0 {
			pct = int(used * 100 / total)
		}

		disks = append(disks, DiskInfo{
			MountPoint:  fields[5],
			TotalGB:     float64(total) / 1024 / 1024 / 1024,
			UsedGB:      float64(used) / 1024 / 1024 / 1024,
			AvailGB:     float64(avail) / 1024 / 1024 / 1024,
			UsedPercent: pct,
			FSType:      fields[0],
		})
	}
	return disks
}

func collectNetwork() NetworkInfo {
	info := NetworkInfo{Hostname: collectHostname()}

	if out, err := exec.Command("hostname", "-I").Output(); err == nil {
		for _, ip := range strings.Fields(string(out)) {
			ip = strings.TrimSpace(ip)
			if ip != "" {
				info.IPAddresses = append(info.IPAddresses, ip)
			}
		}
	}

	if data, err := os.ReadFile("/etc/resolv.conf"); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(line, "nameserver") {
				parts := strings.Fields(line)
				if len(parts) >= 2 {
					info.DNSServers = append(info.DNSServers, parts[1])
				}
			}
		}
	}

	return info
}

func collectFirewall() FirewallInfo {
	out, err := exec.Command("sh", "-c", "nft list ruleset 2>/dev/null | grep -c 'policy drop' || true").Output()
	if err == nil {
		count, _ := strconv.Atoi(strings.TrimSpace(string(out)))
		if count > 0 {
			return FirewallInfo{Enabled: true, Rules: count}
		}
	}

	if _, err := exec.LookPath("nft"); err == nil {
		return FirewallInfo{Enabled: true}
	}

	return FirewallInfo{}
}

func collectTailscale() TailscaleInfo {
	info := TailscaleInfo{}

	if _, err := exec.LookPath("tailscale"); err == nil {
		info.Installed = true

		out, err := exec.Command("tailscale", "status", "--json").Output()
		if err == nil {
			info.Connected = strings.Contains(string(out), `"Online":true`) ||
				!strings.Contains(string(out), `"BackendState":"Stopped"`)
		}

		if out, err := exec.Command("tailscale", "ip", "-4").Output(); err == nil {
			info.IP = strings.TrimSpace(string(out))
		}

		hostname, _ := os.Hostname()
		info.Hostname = hostname
	}

	return info
}

func collectBootloader() string {
	if _, err := os.Stat("/boot/loader/entries"); err == nil {
		return "systemd-boot"
	}
	if _, err := os.Stat("/boot/grub/grub.cfg"); err == nil {
		return "GRUB"
	}
	return "unknown"
}

func collectEncryption() EncryptionInfo {
	return EncryptionInfo{
		LUKS: checkLUKS(),
		SOPS: checkSOPS(),
	}
}

func checkLUKS() bool {
	out, err := exec.Command("lsblk", "-o", "FSTYPE", "-n").Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), "crypto_LUKS")
}

func checkSOPS() bool {
	if _, err := os.Stat(".sops.yaml"); err == nil {
		return true
	}
	if _, err := os.Stat("/run/secrets"); err == nil {
		return true
	}
	return false
}
