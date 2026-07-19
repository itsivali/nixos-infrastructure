package handlers

import (
	"fmt"
	"os"
	"os/user"
	"strings"
)

// runCmdAsUser runs a shell command as DEFAULT_USER (the interactive
// desktop user, read from the DEFAULT_USER env var) inside their
// graphical session, so desktop automation (volume, brightness,
// screenshot, clipboard, app launch, git) can reach the Wayland
// session, D-Bus, and user-installed binaries. The bot runs as
// root, so `sudo -u <user>` needs no password.
func runCmdAsUser(command string, timeoutSecs int) string {
	targetUser := os.Getenv("DEFAULT_USER")
	if targetUser == "" {
		targetUser = "ivali"
	}
	uid := "1000"
	if u, err := user.Lookup(targetUser); err == nil && u.Uid != "" {
		uid = u.Uid
	}
	xdg := "/run/user/" + uid
	dbus := "unix:path=" + xdg + "/bus"
	inner := fmt.Sprintf(
		"export PATH=/run/current-system/sw/bin:/run/wrappers/bin:/usr/bin:/bin "+
			"XDG_RUNTIME_DIR=%s DBUS_SESSION_ADDRESS=%s WAYLAND_DISPLAY=wayland-0 DISPLAY=:0; %s",
		xdg, dbus, command,
	)
	full := "sudo -u " + targetUser + " sh -c " + quoteSh(inner)
	return runCmd(full, timeoutSecs)
}

// quoteSh single-quotes a string for safe embedding in `sh -c '...'`,
// escaping any embedded single quotes.
func quoteSh(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}
