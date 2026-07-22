package bitwarden

import (
	"os"
	"os/exec"
	"strings"
	"time"
)

func CopyToClipboard(text string) error {
	var cmd *exec.Cmd
	if os.Getenv("WAYLAND_DISPLAY") != "" {
		// Do not pass --paste-once when background auto-wipe timer is used so the user can paste multiple times until timeout.
		cmd = exec.Command("wl-copy")
	} else {
		cmd = exec.Command("xclip", "-selection", "clipboard")
	}
	cmd.Stdin = strings.NewReader(text)
	return cmd.Run()
}

func CopyToClipboardWithTimeout(text string, timeoutSec int) error {
	if err := CopyToClipboard(text); err != nil {
		return err
	}
	SendNotification("Bitwarden TUI", "Credential copied to clipboard (auto-clears in 30s)")

	if timeoutSec > 0 {
		go func() {
			time.Sleep(time.Duration(timeoutSec) * time.Second)
			_ = CopyToClipboard("")
			SendNotification("Bitwarden TUI", "Clipboard cleared")
		}()
	}
	return nil
}

func SendNotification(title, message string) {
	_ = exec.Command("notify-send", "-a", "Bitwarden TUI", "-i", "dialog-password", title, message).Run()
}
