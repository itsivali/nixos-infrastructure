package health

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/state"
)

func CheckGNOME() CheckResult {
	if _, err := exec.Command("pgrep", "-x", "gnome-shell").Output(); err == nil {
		return CheckResult{Name: "gnome-shell", State: state.StateHealthy, Message: "GNOME Shell active"}
	}
	return CheckResult{Name: "gnome-shell", State: state.StateWarning, Message: "GNOME Shell not detected"}
}

func CheckWayland() CheckResult {
	if os.Getenv("WAYLAND_DISPLAY") != "" {
		return CheckResult{Name: "wayland", State: state.StateHealthy, Message: "Wayland session active"}
	}
	if _, err := exec.Command("systemctl", "is-active", "display-manager").Output(); err == nil {
		return CheckResult{Name: "wayland", State: state.StateHealthy, Message: "Display manager active"}
	}
	if _, err := exec.Command("pgrep", "-x", "Xorg").Output(); err == nil {
		return CheckResult{Name: "wayland", State: state.StateHealthy, Message: "Xorg fallback running"}
	}
	return CheckResult{Name: "wayland", State: state.StateWarning, Message: "no display server detected"}
}

func CheckGDM() CheckResult {
	out, err := exec.Command("systemctl", "is-active", "gdm").CombinedOutput()
	status := strings.TrimSpace(string(out))
	if err == nil && status == "active" {
		return CheckResult{Name: "gdm", State: state.StateHealthy, Message: "GDM active"}
	}
	return CheckResult{Name: "gdm", State: state.StateWarning, Message: fmt.Sprintf("GDM is %s", status)}
}

func CheckPipeWire() CheckResult {
	if _, err := exec.Command("systemctl", "--user", "is-active", "pipewire").Output(); err == nil {
		return CheckResult{Name: "pipewire", State: state.StateHealthy, Message: "PipeWire active"}
	}
	return CheckResult{Name: "pipewire", State: state.StateWarning, Message: "PipeWire not active"}
}

func CheckWirePlumber() CheckResult {
	if _, err := exec.Command("systemctl", "--user", "is-active", "wireplumber").Output(); err == nil {
		return CheckResult{Name: "wireplumber", State: state.StateHealthy, Message: "WirePlumber active"}
	}
	return CheckResult{Name: "wireplumber", State: state.StateWarning, Message: "WirePlumber not active"}
}

func CheckBluetooth() CheckResult {
	out, err := exec.Command("systemctl", "is-active", "bluetooth").CombinedOutput()
	status := strings.TrimSpace(string(out))
	if err == nil && status == "active" {
		return CheckResult{Name: "bluetooth", State: state.StateHealthy, Message: "Bluetooth service active"}
	}
	return CheckResult{Name: "bluetooth", State: state.StateWarning, Message: fmt.Sprintf("Bluetooth is %s", status)}
}

func CheckBluetoothAdapter() CheckResult {
	out, err := exec.Command("rfkill", "list", "bluetooth").CombinedOutput()
	if err != nil {
		return CheckResult{Name: "bluetooth-adapter", State: state.StateWarning, Message: "rfkill not available"}
	}
	if strings.Contains(string(out), "Soft blocked: no") && strings.Contains(string(out), "Hard blocked: no") {
		return CheckResult{Name: "bluetooth-adapter", State: state.StateHealthy, Message: "adapter unblocked"}
	}
	if strings.Contains(string(out), "Hard blocked: yes") {
		return CheckResult{Name: "bluetooth-adapter", State: state.StateWarning, Message: "adapter hard-blocked (physical switch?)"}
	}
	return CheckResult{Name: "bluetooth-adapter", State: state.StateWarning, Message: "adapter soft-blocked"}
}

func CheckNetworkManager() CheckResult {
	out, err := exec.Command("systemctl", "is-active", "NetworkManager").CombinedOutput()
	status := strings.TrimSpace(string(out))
	if err == nil && status == "active" {
		return CheckResult{Name: "networkmanager", State: state.StateHealthy, Message: "NetworkManager active"}
	}
	return CheckResult{Name: "networkmanager", State: state.StateWarning, Message: fmt.Sprintf("NetworkManager is %s", status)}
}

func CheckWiFi() CheckResult {
	out, err := exec.Command("nmcli", "-t", "-f", "WIFI", "radio").Output()
	if err != nil {
		return CheckResult{Name: "wifi", State: state.StateWarning, Message: "unable to check Wi-Fi state"}
	}
	if strings.TrimSpace(string(out)) != "enabled" {
		return CheckResult{Name: "wifi", State: state.StateWarning, Message: "Wi-Fi radio disabled"}
	}

	out, err = exec.Command("nmcli", "-t", "-f", "STATE", "general").Output()
	if err != nil {
		return CheckResult{Name: "wifi", State: state.StateWarning, Message: "NetworkManager not responding"}
	}
	nmState := strings.TrimSpace(string(out))
	if nmState == "connected" {
		return CheckResult{Name: "wifi", State: state.StateHealthy, Message: "connected"}
	}
	return CheckResult{Name: "wifi", State: state.StateWarning, Message: fmt.Sprintf("NetworkManager state: %s", nmState)}
}

func CheckPowerManagement() CheckResult {
	if _, err := exec.Command("systemctl", "is-active", "upower").Output(); err != nil {
		return CheckResult{Name: "power", State: state.StateWarning, Message: "upower not active"}
	}
	if _, err := os.Stat("/sys/class/power_supply"); err != nil {
		return CheckResult{Name: "power", State: state.StateWarning, Message: "no power supply devices found"}
	}
	return CheckResult{Name: "power", State: state.StateHealthy, Message: "power management active"}
}

func CheckLocker() CheckResult {
	lockers := []string{"gnome-screensaver", "xdg-screensaver", "light-locker", "xscreensaver", "xss-lock"}
	for _, l := range lockers {
		if _, err := exec.Command("which", l).Output(); err == nil {
			return CheckResult{Name: "locker", State: state.StateHealthy, Message: fmt.Sprintf("%s available", l)}
		}
	}
	// GNOME Shell's built-in locking is the primary screen locker on Wayland;
	// external lockers are only a fallback check.
	if os.Getenv("XDG_SESSION_TYPE") == "wayland" {
		return CheckResult{Name: "locker", State: state.StateHealthy, Message: "GNOME Shell built-in lock (Wayland)"}
	}
	return CheckResult{Name: "locker", State: state.StateWarning, Message: "no screen locker found"}
}

func CheckAMDGPU() CheckResult {
	if _, err := os.Stat("/sys/class/drm/card0"); err != nil {
		return CheckResult{Name: "amdgpu", State: state.StateWarning, Message: "no DRM card found"}
	}
	out, err := os.ReadFile("/sys/class/drm/card0/device/driver")
	if err != nil {
		return CheckResult{Name: "amdgpu", State: state.StateWarning, Message: "unable to read driver"}
	}
	if strings.Contains(string(out), "amdgpu") {
		return CheckResult{Name: "amdgpu", State: state.StateHealthy, Message: "amdgpu driver bound"}
	}
	return CheckResult{Name: "amdgpu", State: state.StateWarning, Message: "amdgpu driver not bound"}
}

func CheckVulkan() CheckResult {
	if _, err := exec.Command("which", "vulkaninfo").Output(); err != nil {
		return CheckResult{Name: "vulkan", State: state.StateWarning, Message: "vulkaninfo not found (Vulkan may not be installed)"}
	}
	out, err := exec.Command("vulkaninfo", "--summary").Output()
	if err != nil {
		return CheckResult{Name: "vulkan", State: state.StateWarning, Message: "vulkaninfo failed"}
	}
	if strings.Contains(string(out), "AMD") {
		return CheckResult{Name: "vulkan", State: state.StateHealthy, Message: "AMD Vulkan ICD present"}
	}
	return CheckResult{Name: "vulkan", State: state.StateHealthy, Message: "Vulkan available"}
}

func CheckTouchpad() CheckResult {
	out, err := exec.Command("libinput", "list-devices").Output()
	if err != nil {
		return CheckResult{Name: "touchpad", State: state.StateWarning, Message: "libinput not available"}
	}
	if strings.Contains(string(out), "touchpad") || strings.Contains(string(out), "Touchpad") {
		return CheckResult{Name: "touchpad", State: state.StateHealthy, Message: "touchpad detected"}
	}
	return CheckResult{Name: "touchpad", State: state.StateWarning, Message: "no touchpad found"}
}

func CheckWebcam() CheckResult {
	if _, err := os.Stat("/dev/video0"); err != nil {
		return CheckResult{Name: "webcam", State: state.StateWarning, Message: "no /dev/video0 device"}
	}
	return CheckResult{Name: "webcam", State: state.StateHealthy, Message: "webcam device present"}
}

func CheckPlatformProfile() CheckResult {
	data, err := os.ReadFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
	if err != nil {
		return CheckResult{Name: "platform-profile", State: state.StateWarning, Message: "unable to read governor"}
	}
	governor := strings.TrimSpace(string(data))
	if governor == "schedutil" || governor == "ondemand" || governor == "conservative" {
		return CheckResult{Name: "platform-profile", State: state.StateHealthy, Message: fmt.Sprintf("governor: %s", governor)}
	}
	return CheckResult{Name: "platform-profile", State: state.StateWarning, Message: fmt.Sprintf("governor: %s", governor)}
}

func RunAllDesktopChecks() []CheckResult {
	return []CheckResult{
		CheckGNOME(),
		CheckWayland(),
		CheckGDM(),
		CheckPipeWire(),
		CheckWirePlumber(),
		CheckBluetooth(),
		CheckBluetoothAdapter(),
		CheckNetworkManager(),
		CheckWiFi(),
		CheckPowerManagement(),
		CheckLocker(),
		CheckAMDGPU(),
		CheckVulkan(),
		CheckTouchpad(),
		CheckWebcam(),
		CheckPlatformProfile(),
	}
}