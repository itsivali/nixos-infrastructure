package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
)

// Desktop commands — GUI, media, and window management.

type AppsCommand struct {
	api *telegram.API
}

func NewAppsCommand(config *telegram.Config) *AppsCommand {
	return &AppsCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *AppsCommand) Name() string                      { return "apps" }
func (c *AppsCommand) Description() string               { return "List discovered applications" }
func (c *AppsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *AppsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmdAsUser("find /run/current-system/sw/share/applications /usr/share/applications -name '*.desktop' 2>/dev/null | head -30 || echo 'No applications found'", 10)
	return c.api.SendLongMessage(msg.ChatID, "```"+output+"```", 3500)
}

type OpenCommand struct {
	api *telegram.API
}

func NewOpenCommand(config *telegram.Config) *OpenCommand {
	return &OpenCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *OpenCommand) Name() string                      { return "open" }
func (c *OpenCommand) Description() string               { return "Launch any application" }
func (c *OpenCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *OpenCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/open <application|url>`")
	}
	output := runCmdAsUser(fmt.Sprintf("nohup %s &>/dev/null &", args), 5)
	_ = output
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Launched: `%s`", args))
}

type VolumeCommand struct {
	api *telegram.API
}

func NewVolumeCommand(config *telegram.Config) *VolumeCommand {
	return &VolumeCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *VolumeCommand) Name() string                      { return "volume" }
func (c *VolumeCommand) Description() string               { return "Volume control" }
func (c *VolumeCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *VolumeCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		output := runCmdAsUser("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'wpctl not available'", 5)
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("🔊 %s", output))
	}
	output := runCmdAsUser(fmt.Sprintf("wpctl set-volume @DEFAULT_AUDIO_SINK@ %s 2>/dev/null", args), 5)
	_ = output
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("🔊 Volume set to %s", args))
}

type MuteCommand struct {
	api *telegram.API
}

func NewMuteCommand(config *telegram.Config) *MuteCommand {
	return &MuteCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *MuteCommand) Name() string                      { return "mute" }
func (c *MuteCommand) Description() string               { return "Mute audio" }
func (c *MuteCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *MuteCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	runCmdAsUser("wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 2>/dev/null", 5)
	return c.api.SendMarkdown(msg.ChatID, "🔇 Muted")
}

type UnmuteCommand struct {
	api *telegram.API
}

func NewUnmuteCommand(config *telegram.Config) *UnmuteCommand {
	return &UnmuteCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *UnmuteCommand) Name() string                      { return "unmute" }
func (c *UnmuteCommand) Description() string               { return "Unmute audio" }
func (c *UnmuteCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *UnmuteCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	runCmdAsUser("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null", 5)
	return c.api.SendMarkdown(msg.ChatID, "🔊 Unmuted")
}

type BrightnessCommand struct {
	api *telegram.API
}

func NewBrightnessCommand(config *telegram.Config) *BrightnessCommand {
	return &BrightnessCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *BrightnessCommand) Name() string                      { return "brightness" }
func (c *BrightnessCommand) Description() string               { return "Brightness control" }
func (c *BrightnessCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *BrightnessCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		output := runCmdAsUser("brightnessctl info 2>/dev/null | grep -oP '\\d+%' | head -1 || echo 'unknown'", 5)
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("🔆 Brightness: %s", output))
	}
	output := runCmdAsUser(fmt.Sprintf("brightnessctl set %s 2>/dev/null", args), 5)
	_ = output
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("🔆 Brightness set to %s", args))
}

type ScreenshotCommand struct {
	api *telegram.API
}

func NewScreenshotCommand(config *telegram.Config) *ScreenshotCommand {
	return &ScreenshotCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *ScreenshotCommand) Name() string                      { return "screenshot" }
func (c *ScreenshotCommand) Description() string               { return "Capture desktop" }
func (c *ScreenshotCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *ScreenshotCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "Capturing screenshot...")
	output := runCmdAsUser("gnome-screenshot -f /tmp/screenshot.png 2>/dev/null && echo OK || echo FAIL", 10)
	if strings.Contains(output, "OK") {
		if err := c.api.SendPhoto(msg.ChatID, "/tmp/screenshot.png", "Desktop screenshot"); err != nil {
			return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Screenshot captured but failed to send: `%s`", err))
		}
		return nil
	}
	return c.api.SendMarkdown(msg.ChatID, "Screenshot failed")
}

type ClipboardCommand struct {
	api *telegram.API
}

func NewClipboardCommand(config *telegram.Config) *ClipboardCommand {
	return &ClipboardCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *ClipboardCommand) Name() string                      { return "clipboard" }
func (c *ClipboardCommand) Description() string               { return "Clipboard operations" }
func (c *ClipboardCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *ClipboardCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if strings.HasPrefix(args, "set ") {
		content := strings.TrimPrefix(args, "set ")
		runCmdAsUser(fmt.Sprintf("echo -n '%s' | wl-copy 2>/dev/null", content), 5)
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("📋 Clipboard set to: `%s`", content))
	}
	output := runCmdAsUser("wl-paste 2>/dev/null || echo 'Clipboard empty'", 5)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("📋 *Clipboard:*\n```\n%s\n```", output), 3500)
}

type DesktopPowerCommand struct {
	api *telegram.API
}

func NewDesktopPowerCommand(config *telegram.Config) *DesktopPowerCommand {
	return &DesktopPowerCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *DesktopPowerCommand) Name() string                      { return "desktop_power" }
func (c *DesktopPowerCommand) Description() string               { return "Power options (suspend/lock)" }
func (c *DesktopPowerCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *DesktopPowerCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	switch args {
	case "suspend":
		runCmd("systemctl suspend", 5)
		return c.api.SendMarkdown(msg.ChatID, "Suspended")
	case "lock":
		runCmdAsUser("gnome-screensaver-command -l 2>/dev/null || loginctl lock-session", 5)
		return c.api.SendMarkdown(msg.ChatID, "Locked")
	default:
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/desktop_power suspend|lock`")
	}
}

type FirefoxCommand struct {
	api *telegram.API
}

func NewFirefoxCommand(config *telegram.Config) *FirefoxCommand {
	return &FirefoxCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *FirefoxCommand) Name() string                      { return "firefox" }
func (c *FirefoxCommand) Description() string               { return "Open Firefox" }
func (c *FirefoxCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *FirefoxCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	runCmdAsUser("nohup firefox &>/dev/null &", 5)
	return c.api.SendMarkdown(msg.ChatID, "Opening Firefox...")
}

type WindowsCommand struct {
	api *telegram.API
}

func NewWindowsCommand(config *telegram.Config) *WindowsCommand {
	return &WindowsCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *WindowsCommand) Name() string                      { return "windows" }
func (c *WindowsCommand) Description() string               { return "Window management" }
func (c *WindowsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *WindowsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmdAsUser("wmctrl -l 2>/dev/null || echo 'wmctrl not available'", 5)
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("```%s\n```", output), 3500)
}

type WorkspaceCommand struct {
	api *telegram.API
}

func NewWorkspaceCommand(config *telegram.Config) *WorkspaceCommand {
	return &WorkspaceCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *WorkspaceCommand) Name() string                      { return "workspace" }
func (c *WorkspaceCommand) Description() string               { return "Workspace management" }
func (c *WorkspaceCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *WorkspaceCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := runCmdAsUser("gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval 'global.workspace_manager.get_n_workspaces()' 2>/dev/null || echo 'GNOME not available'", 5)
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Workspaces: %s", output))
}

type MonitorOnCommand struct {
	api *telegram.API
}

func NewMonitorOnCommand(config *telegram.Config) *MonitorOnCommand {
	return &MonitorOnCommand{api: telegram.NewAPI(config.BotToken)}
}

func (c *MonitorOnCommand) Name() string                      { return "monitoron" }
func (c *MonitorOnCommand) Description() string               { return "Turn on monitor" }
func (c *MonitorOnCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *MonitorOnCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	runCmdAsUser("xset dpms force on 2>/dev/null || true", 5)
	return c.api.SendMarkdown(msg.ChatID, "Monitor turned on")
}
