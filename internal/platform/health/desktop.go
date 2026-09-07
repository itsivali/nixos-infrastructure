package health

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/state"
)

func CheckXFCE() CheckResult {
	if _, err := exec.Command("systemctl", "--user", "is-active", "xfce4-session").Output(); err == nil {
		return CheckResult{Name: "xfce-session", State: state.StateHealthy, Message: "XFCE session active"}
	}
	if _, err := exec.Command("pgrep", "-x", "xfwm4").Output(); err == nil {
		return CheckResult{Name: "xfce-session", State: state.StateHealthy, Message: "XFCE session active (xfwm4 running)"}
	}
	return CheckResult{Name: "xfce-session", State: state.StateWarning, Message: "XFCE session not detected"}
}

func CheckXServer() CheckResult {
	if _, err := exec.Command("systemctl", "is-active", "display-manager").Output(); err == nil {
		return CheckResult{Name: "xserver", State: state.StateHealthy, Message: "Display manager active"}
	}
	if _, err := exec.Command("pgrep", "-x", "Xorg").Output(); err == nil {
		return CheckResult{Name: "xserver", State: state.StateHealthy, Message: "Xorg running"}
	}
	return CheckResult{Name: "xserver", State: state.StateWarning, Message: "X server not detected"}
}

func CheckLightDM() CheckResult {
	out, err := exec.Command("systemctl", "is-active", "lightdm").CombinedOutput()
	status := strings.TrimSpace(string(out))
	if err == nil && status == "active" {
		return CheckResult{Name: "lightdm", State: state.StateHealthy, Message: "LightDM active"}
	}
	return CheckResult{Name: "lightdm", State: state.StateWarning, Message: fmt.Sprintf("LightDM is %s", status)}
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

func CheckNoGNOMEShell() CheckResult {
	if _, err := exec.Command("pgrep", "-x", "gnome-shell").Output(); err == nil {
		return CheckResult{Name: "no-gnome-shell", State: state.StateWarning, Message: "GNOME Shell is running"}
	}
	return CheckResult{Name: "no-gnome-shell", State: state.StateHealthy, Message: "no GNOME Shell process"}
}

func CheckNoGDM() CheckResult {
	out, err := exec.Command("systemctl", "is-active", "gdm").CombinedOutput()
	status := strings.TrimSpace(string(out))
	if err == nil && status == "active" {
		return CheckResult{Name: "no-gdm", State: state.StateWarning, Message: "GDM is active (should be LightDM)"}
	}
	return CheckResult{Name: "no-gdm", State: state.StateHealthy, Message: "GDM not active"}
}

func CheckLocker() CheckResult {
	lockers := []string{"light-locker", "xfce4-screensaver", "xscreensaver", "xss-lock"}
	for _, l := range lockers {
		if _, err := exec.Command("which", l).Output(); err == nil {
			return CheckResult{Name: "locker", State: state.StateHealthy, Message: fmt.Sprintf("%s available", l)}
		}
	}
	return CheckResult{Name: "locker", State: state.StateWarning, Message: "no screen locker found"}
}

func RunAllDesktopChecks() []CheckResult {
	return []CheckResult{
		CheckXFCE(),
		CheckXServer(),
		CheckLightDM(),
		CheckPipeWire(),
		CheckWirePlumber(),
		CheckBluetooth(),
		CheckNetworkManager(),
		CheckWiFi(),
		CheckPowerManagement(),
		CheckNoGNOMEShell(),
		CheckNoGDM(),
		CheckLocker(),
	}
}
