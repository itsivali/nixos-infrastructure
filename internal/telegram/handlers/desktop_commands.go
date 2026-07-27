package handlers

import (
	"context"
	"fmt"
	"strings"

	"github.com/itsivali/nixos-infrastructure/internal/telegram"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/renderer"
	"github.com/itsivali/nixos-infrastructure/internal/telegram/services"
)

type AppsCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewAppsCommand(api *telegram.API, svc *services.Container) *AppsCommand {
	return &AppsCommand{api: api, svc: svc}
}

func (c *AppsCommand) Name() string                      { return "apps" }
func (c *AppsCommand) Description() string               { return "List discovered applications" }
func (c *AppsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *AppsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Desktop.ListApps()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type OpenCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewOpenCommand(api *telegram.API, svc *services.Container) *OpenCommand {
	return &OpenCommand{api: api, svc: svc}
}

func (c *OpenCommand) Name() string                      { return "open" }
func (c *OpenCommand) Description() string               { return "Launch any application" }
func (c *OpenCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *OpenCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/open <application|url>`")
	}
	result := c.svc.Desktop.LaunchApp(args)
	return c.api.SendMarkdown(msg.ChatID, result)
}

type VolumeCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewVolumeCommand(api *telegram.API, svc *services.Container) *VolumeCommand {
	return &VolumeCommand{api: api, svc: svc}
}

func (c *VolumeCommand) Name() string                      { return "volume" }
func (c *VolumeCommand) Description() string               { return "Volume control" }
func (c *VolumeCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *VolumeCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		output := c.svc.Desktop.VolumeGet()
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("🔊 %s", output))
	}
	result := c.svc.Desktop.VolumeSet(args)
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("🔊 %s", result))
}

type MuteCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewMuteCommand(api *telegram.API, svc *services.Container) *MuteCommand {
	return &MuteCommand{api: api, svc: svc}
}

func (c *MuteCommand) Name() string                      { return "mute" }
func (c *MuteCommand) Description() string               { return "Mute audio" }
func (c *MuteCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *MuteCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	c.svc.Desktop.Mute()
	return c.api.SendMarkdown(msg.ChatID, "🔇 Muted")
}

type UnmuteCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewUnmuteCommand(api *telegram.API, svc *services.Container) *UnmuteCommand {
	return &UnmuteCommand{api: api, svc: svc}
}

func (c *UnmuteCommand) Name() string                      { return "unmute" }
func (c *UnmuteCommand) Description() string               { return "Unmute audio" }
func (c *UnmuteCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *UnmuteCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	c.svc.Desktop.Unmute()
	return c.api.SendMarkdown(msg.ChatID, "🔊 Unmuted")
}

type BrightnessCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewBrightnessCommand(api *telegram.API, svc *services.Container) *BrightnessCommand {
	return &BrightnessCommand{api: api, svc: svc}
}

func (c *BrightnessCommand) Name() string                      { return "brightness" }
func (c *BrightnessCommand) Description() string               { return "Brightness control" }
func (c *BrightnessCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *BrightnessCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if args == "" {
		output := c.svc.Desktop.BrightnessGet()
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("🔆 Brightness: %s", output))
	}
	result := c.svc.Desktop.BrightnessSet(args)
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("🔆 %s", result))
}

type ScreenshotCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewScreenshotCommand(api *telegram.API, svc *services.Container) *ScreenshotCommand {
	return &ScreenshotCommand{api: api, svc: svc}
}

func (c *ScreenshotCommand) Name() string                      { return "screenshot" }
func (c *ScreenshotCommand) Description() string               { return "Capture desktop" }
func (c *ScreenshotCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *ScreenshotCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	_ = c.api.SendMarkdown(msg.ChatID, "Capturing screenshot...")
	filePath, ok := c.svc.Desktop.Screenshot()
	if ok {
		if err := c.api.SendPhoto(msg.ChatID, filePath, "Desktop screenshot"); err != nil {
			return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Screenshot captured but failed to send: `%s`", err))
		}
		return nil
	}
	return c.api.SendMarkdown(msg.ChatID, "Screenshot failed")
}

type ClipboardCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewClipboardCommand(api *telegram.API, svc *services.Container) *ClipboardCommand {
	return &ClipboardCommand{api: api, svc: svc}
}

func (c *ClipboardCommand) Name() string                      { return "clipboard" }
func (c *ClipboardCommand) Description() string               { return "Clipboard operations" }
func (c *ClipboardCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *ClipboardCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	if strings.HasPrefix(args, "set ") {
		content := strings.TrimPrefix(args, "set ")
		result := c.svc.Desktop.ClipboardSet(content)
		return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("📋 %s", result))
	}
	output := c.svc.Desktop.ClipboardGet()
	return c.api.SendLongMessage(msg.ChatID, fmt.Sprintf("📋 *Clipboard:*\n%s", renderer.CodeBlock(output)), 3500)
}

type DesktopPowerCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewDesktopPowerCommand(api *telegram.API, svc *services.Container) *DesktopPowerCommand {
	return &DesktopPowerCommand{api: api, svc: svc}
}

func (c *DesktopPowerCommand) Name() string                      { return "desktop_power" }
func (c *DesktopPowerCommand) Description() string               { return "Power options (suspend/lock)" }
func (c *DesktopPowerCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *DesktopPowerCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	args := strings.TrimSpace(msg.Args)
	switch args {
	case "suspend":
		c.svc.Desktop.Suspend()
		return c.api.SendMarkdown(msg.ChatID, "Suspended")
	case "lock":
		c.svc.Desktop.Lock()
		return c.api.SendMarkdown(msg.ChatID, "Locked")
	default:
		return c.api.SendMarkdown(msg.ChatID, "Usage: `/desktop_power suspend|lock`")
	}
}

type FirefoxCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewFirefoxCommand(api *telegram.API, svc *services.Container) *FirefoxCommand {
	return &FirefoxCommand{api: api, svc: svc}
}

func (c *FirefoxCommand) Name() string                      { return "firefox" }
func (c *FirefoxCommand) Description() string               { return "Open Firefox" }
func (c *FirefoxCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *FirefoxCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	c.svc.Desktop.OpenFirefox()
	return c.api.SendMarkdown(msg.ChatID, "Opening Firefox...")
}

type WindowsCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewWindowsCommand(api *telegram.API, svc *services.Container) *WindowsCommand {
	return &WindowsCommand{api: api, svc: svc}
}

func (c *WindowsCommand) Name() string                      { return "windows" }
func (c *WindowsCommand) Description() string               { return "Window management" }
func (c *WindowsCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *WindowsCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Desktop.ListWindows()
	return c.api.SendLongMessage(msg.ChatID, renderer.CodeBlock(output), 3500)
}

type WorkspaceCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewWorkspaceCommand(api *telegram.API, svc *services.Container) *WorkspaceCommand {
	return &WorkspaceCommand{api: api, svc: svc}
}

func (c *WorkspaceCommand) Name() string                      { return "workspace" }
func (c *WorkspaceCommand) Description() string               { return "Workspace management" }
func (c *WorkspaceCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *WorkspaceCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	output := c.svc.Desktop.Workspaces()
	return c.api.SendMarkdown(msg.ChatID, fmt.Sprintf("Workspaces: %s", output))
}

type MonitorOnCommand struct {
	api *telegram.API
	svc *services.Container
}

func NewMonitorOnCommand(api *telegram.API, svc *services.Container) *MonitorOnCommand {
	return &MonitorOnCommand{api: api, svc: svc}
}

func (c *MonitorOnCommand) Name() string                      { return "monitoron" }
func (c *MonitorOnCommand) Description() string               { return "Turn on monitor" }
func (c *MonitorOnCommand) RequiredPermission() telegram.Role { return telegram.RoleUser }

func (c *MonitorOnCommand) Execute(ctx context.Context, msg *telegram.Message) error {
	c.svc.Desktop.MonitorOn()
	return c.api.SendMarkdown(msg.ChatID, "Monitor turned on")
}
