package services

import (
	"fmt"
	"strings"
)

// DesktopService provides GUI and desktop automation operations.
type DesktopService struct {
	runner *Runner
}

// NewDesktopService creates a new DesktopService.
func NewDesktopService(runner *Runner) *DesktopService {
	return &DesktopService{runner: runner}
}

// ListApps returns discovered .desktop applications.
func (s *DesktopService) ListApps() string {
	return s.runner.RunAsUser(
		"find /run/current-system/sw/share/applications /usr/share/applications -name '*.desktop' 2>/dev/null | head -30 || echo 'No applications found'", 10)
}

// LaunchApp launches an application by name or URL.
func (s *DesktopService) LaunchApp(app string) string {
	s.runner.RunAsUser(fmt.Sprintf("nohup %s &>/dev/null &", app), 5)
	return fmt.Sprintf("Launched: `%s`", app)
}

// VolumeGet returns the current volume level.
func (s *DesktopService) VolumeGet() string {
	return s.runner.RunAsUser("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'wpctl not available'", 5)
}

// VolumeSet sets the volume level.
func (s *DesktopService) VolumeSet(level string) string {
	s.runner.RunAsUser(fmt.Sprintf("wpctl set-volume @DEFAULT_AUDIO_SINK@ %s 2>/dev/null", QuoteSh(level)), 5)
	return fmt.Sprintf("Volume set to %s", level)
}

// Mute mutes the default audio sink.
func (s *DesktopService) Mute() string {
	s.runner.RunAsUser("wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 2>/dev/null", 5)
	return "Muted"
}

// Unmute unmutes the default audio sink.
func (s *DesktopService) Unmute() string {
	s.runner.RunAsUser("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null", 5)
	return "Unmuted"
}

// BrightnessGet returns the current brightness percentage.
func (s *DesktopService) BrightnessGet() string {
	return s.runner.RunAsUser(
		"brightnessctl info 2>/dev/null | grep -oP '\\d+%' | head -1 || echo 'unknown'", 5)
}

// BrightnessSet sets the brightness level.
func (s *DesktopService) BrightnessSet(level string) string {
	s.runner.RunAsUser(fmt.Sprintf("brightnessctl set %s 2>/dev/null", QuoteSh(level)), 5)
	return fmt.Sprintf("Brightness set to %s", level)
}

// Screenshot captures the desktop to a file via the GNOME Shell screenshot
// service. Returns (filePath, success).
func (s *DesktopService) Screenshot() (string, bool) {
	// org.gnome.Shell.Screenshot.Screenshot(include_cursor, flash, filename)
	// writes to the given absolute path and returns (success, filename_used).
	output := s.runner.RunAsUser(
		"gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Screenshot.Screenshot false false /tmp/screenshot.png 2>/dev/null || echo FAIL", 10)
	return "/tmp/screenshot.png", strings.Contains(output, "true")
}

// ClipboardGet returns the clipboard contents.
func (s *DesktopService) ClipboardGet() string {
	return s.runner.RunAsUser("wl-paste 2>/dev/null || echo 'Clipboard empty'", 5)
}

// ClipboardSet sets the clipboard contents.
func (s *DesktopService) ClipboardSet(content string) string {
	s.runner.RunAsUser(fmt.Sprintf("echo -n %s | wl-copy 2>/dev/null", QuoteSh(content)), 5)
	return fmt.Sprintf("Clipboard set to: `%s`", content)
}

// Suspend suspends the system.
func (s *DesktopService) Suspend() string {
	s.runner.Run("systemctl suspend", 5)
	return "Suspended"
}

// Lock locks the desktop session. loginctl is the canonical trigger on GNOME
// (gnome-session listens for the Lock signal); the ScreenSaver D-Bus method is
// the direct fallback.
func (s *DesktopService) Lock() string {
	s.runner.RunAsUser(
		"loginctl lock-session 2>/dev/null || gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.Lock 2>/dev/null || true", 5)
	return "Locked"
}

// OpenFirefox launches Firefox.
func (s *DesktopService) OpenFirefox() string {
	s.runner.RunAsUser("nohup firefox &>/dev/null &", 5)
	return "Opening Firefox..."
}

// ListWindows returns the titles of the open windows, via GNOME Shell
// introspection (works on Wayland; wmctrl is X11-only and not used).
func (s *DesktopService) ListWindows() string {
	out := strings.TrimSpace(s.runner.RunAsUser(
		`gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Introspect.GetWindows 2>/dev/null | grep -oP "'title': <'[^']*'>" | sed -e "s/^'title': <'//" -e "s/'>$//" | grep -v '^$' | sort -u`, 10))
	if out == "" {
		return "No open windows"
	}
	return out
}

// Workspaces reports the GNOME workspace configuration. GNOME uses dynamic
// workspaces, so this reports the dynamic-workspaces flag plus the configured
// workspace count rather than enumerating named workspaces.
func (s *DesktopService) Workspaces() string {
	out := s.runner.RunAsUser(
		"echo \"dynamic-workspaces=$(gsettings get org.gnome.mutter dynamic-workspaces 2>/dev/null) num-workspaces=$(gsettings get org.gnome.desktop.wm.preferences num-workspaces 2>/dev/null)\" 2>/dev/null || echo 'GNOME workspace info unavailable'", 5)
	return out
}

// MonitorOn wakes the monitor(s). On Wayland the screen is dimmed by the
// gnome-session idler, so SetActive(false) re-activates the session; xset is
// kept as an X11 fallback.
func (s *DesktopService) MonitorOn() string {
	s.runner.RunAsUser(
		"gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false 2>/dev/null || xset dpms force on 2>/dev/null || true", 5)
	return "Monitor turned on"
}
