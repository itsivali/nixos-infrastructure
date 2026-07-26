package inventory

import (
	"testing"
)

func TestCollectHostname(t *testing.T) {
	h := collectHostname()
	if h == "" {
		t.Error("expected non-empty hostname")
	}
}

func TestCollectOS(t *testing.T) {
	os := collectOS()
	if os == "" {
		t.Error("expected non-empty OS string")
	}
}

func TestCollectKernel(t *testing.T) {
	k := collectKernel()
	if k == "" {
		t.Error("expected non-empty kernel version")
	}
}

func TestCollectUptime(t *testing.T) {
	u := collectUptime()
	if u <= 0 {
		t.Error("expected positive uptime")
	}
}

func TestCollectCPU(t *testing.T) {
	cpu := collectCPU()
	if cpu.Cores <= 0 {
		t.Error("expected at least 1 core")
	}
	if cpu.Threads <= 0 {
		t.Error("expected at least 1 thread")
	}
}

func TestCollectMemory(t *testing.T) {
	mem := collectMemory()
	if mem.TotalGB <= 0 {
		t.Error("expected positive total memory")
	}
}

func TestCollectStorage(t *testing.T) {
	disks := collectStorage()
	if len(disks) == 0 {
		t.Log("no disks found (expected in CI/containers)")
	}
	for _, d := range disks {
		if d.TotalGB <= 0 {
			t.Errorf("disk %s: expected positive total", d.MountPoint)
		}
	}
}

func TestCollectNetwork(t *testing.T) {
	net := collectNetwork()
	if net.Hostname == "" {
		t.Error("expected non-empty hostname")
	}
}

func TestCollectBootloader(t *testing.T) {
	b := collectBootloader()
	if b == "" {
		t.Error("expected non-empty bootloader")
	}
}

func TestCollectEncryption(t *testing.T) {
	e := collectEncryption()
	if e.SOPS == false && e.LUKS == false {
		t.Log("no encryption detected (expected in some environments)")
	}
}

func TestCollectGPU(t *testing.T) {
	gpus := collectGPU()
	t.Logf("detected %d GPU(s)", len(gpus))
}

func TestCollectFirewall(t *testing.T) {
	fw := collectFirewall()
	if !fw.Enabled {
		t.Log("firewall not enabled (expected in some environments)")
	}
}

func TestCollectTailscale(t *testing.T) {
	ts := collectTailscale()
	if !ts.Installed {
		t.Log("tailscale not installed (expected in some environments)")
	}
}

func TestCollectFull(t *testing.T) {
	inv := Collect()
	if inv == nil {
		t.Fatal("expected non-nil inventory")
	}
	if inv.Hostname == "" {
		t.Error("expected non-empty hostname")
	}
	if inv.Kernel == "" {
		t.Error("expected non-empty kernel")
	}
	if inv.OS == "" {
		t.Error("expected non-empty OS")
	}
}
