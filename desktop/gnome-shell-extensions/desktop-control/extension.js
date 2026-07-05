// Desktop Control — GNOME Shell extension for Telegram bot
// Provides a D-Bus API for remote window/workspace control.
// UUID: desktop-control@prague.ivali
//
// GNOME Shell 45+ ESM extension. Legacy `imports.gi` / bare `log()` /
// implicit `Shell` global are gone — everything must be an explicit
// ES module import, and enable()/disable() live on a class instance.

import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const IFACE = 'org.gnome.Shell.Extensions.DesktopControl';
const OBJECT_PATH = '/org/gnome/Shell/Extensions/DesktopControl';

const DesktopControlIface = `
<node>
  <interface name="${IFACE}">
    <method name="ListWindows">
      <arg type="s" name="windows_json" direction="out"/>
    </method>
    <method name="FocusWindow">
      <arg type="s" name="title" direction="in"/>
      <arg type="b" name="success" direction="out"/>
    </method>
    <method name="CloseWindow">
      <arg type="s" name="title" direction="in"/>
      <arg type="b" name="success" direction="out"/>
    </method>
    <method name="GetActiveWorkspace">
      <arg type="i" name="index" direction="out"/>
    </method>
    <method name="GetWorkspaceCount">
      <arg type="i" name="count" direction="out"/>
    </method>
    <method name="SwitchWorkspace">
      <arg type="i" name="index" direction="in"/>
      <arg type="b" name="success" direction="out"/>
    </method>
    <method name="GetRunningApps">
      <arg type="s" name="apps_json" direction="out"/>
    </method>
  </interface>
</node>
`;

export default class DesktopControlExtension extends Extension {
    // ── Window iteration (works across Mutter versions) ──────────────────

    _getWindows() {
        if (typeof global.display.get_windows === 'function')
            return global.display.get_windows();

        if (typeof global.display.get_tab_list === 'function') {
            const tabList = Meta.TabList || {};
            return global.display.get_tab_list(tabList.NORMAL_ALL || 0, null);
        }

        if (typeof global.get_window_actors === 'function')
            return global.get_window_actors().map(a => a.meta_window);

        console.log('DesktopControl: no window iteration method available');
        return [];
    }

    // ── Window listing ─────────────────────────────────────────────────────

    _listWindows() {
        let wins = [];
        try {
            const windows = this._getWindows();
            for (const w of windows) {
                if (w.is_monitor)
                    continue;
                wins.push({
                    title: w.get_title() || '',
                    wm_class: w.get_wm_class() || '',
                    pid: w.get_pid(),
                    workspace: w.get_workspace() ? w.get_workspace().index() : -1,
                    minimized: w.is_minimized(),
                });
            }
        } catch (e) {
            console.log(`DesktopControl: _listWindows failed: ${e}`);
        }
        return JSON.stringify(wins);
    }

    // ── Window focusing ────────────────────────────────────────────────────

    _focusWindow(title) {
        try {
            const windows = this._getWindows();
            const lower = title.toLowerCase();
            for (const w of windows) {
                if (w.is_monitor)
                    continue;
                const t = (w.get_title() || '').toLowerCase();
                const wm = (w.get_wm_class() || '').toLowerCase();
                if (t.includes(lower) || wm.includes(lower)) {
                    w.activate(global.get_current_time());
                    return true;
                }
            }
        } catch (e) {
            console.log(`DesktopControl: _focusWindow failed: ${e}`);
        }
        return false;
    }

    // ── Window closing ─────────────────────────────────────────────────────

    _closeWindow(title) {
        try {
            const windows = this._getWindows();
            const lower = title.toLowerCase();
            for (const w of windows) {
                if (w.is_monitor)
                    continue;
                const t = (w.get_title() || '').toLowerCase();
                const wm = (w.get_wm_class() || '').toLowerCase();
                if (t.includes(lower) || wm.includes(lower)) {
                    w.delete(global.get_current_time());
                    return true;
                }
            }
        } catch (e) {
            console.log(`DesktopControl: _closeWindow failed: ${e}`);
        }
        return false;
    }

    // ── Workspace methods ───────────────────────────────────────────────────

    _getActiveWorkspace() {
        return global.workspace_manager.get_active_workspace_index();
    }

    _getWorkspaceCount() {
        return global.workspace_manager.get_n_workspaces();
    }

    _switchWorkspace(index) {
        const ws = global.workspace_manager.get_workspace_by_index(index);
        if (!ws)
            return false;
        ws.activate(global.get_current_time());
        return true;
    }

    // ── Running apps ────────────────────────────────────────────────────────

    _getRunningApps() {
        let apps = [];
        try {
            const appSys = Shell.AppSystem.get_default();
            const running = appSys.get_running();
            for (const app of running) {
                apps.push({
                    id: app.get_id(),
                    name: app.get_name(),
                    wm_class: app.get_wm_class(),
                });
            }
        } catch (e) {
            console.log(`DesktopControl: _getRunningApps failed: ${e}`);
        }
        return JSON.stringify(apps);
    }

    // ── D-Bus implementation ────────────────────────────────────────────────

    _buildDBusImpl() {
        return {
            ListWindows: () => [this._listWindows()],
            FocusWindow: ([title]) => [this._focusWindow(title)],
            CloseWindow: ([title]) => [this._closeWindow(title)],
            GetActiveWorkspace: () => [this._getActiveWorkspace()],
            GetWorkspaceCount: () => [this._getWorkspaceCount()],
            SwitchWorkspace: ([index]) => [this._switchWorkspace(index)],
            GetRunningApps: () => [this._getRunningApps()],
        };
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    enable() {
        try {
            const info = Gio.DBusNodeInfo.new_for_xml(DesktopControlIface);
            this._dbusImpl = Gio.DBusExportedObject.wrapJSObject(
                info.interfaces[0], this._buildDBusImpl());
            this._dbusImpl.export(Gio.DBus.session, OBJECT_PATH);
            console.log('DesktopControl extension enabled — D-Bus service registered');
        } catch (e) {
            console.log(`DesktopControl: enable failed: ${e}`);
        }
    }

    disable() {
        if (this._dbusImpl) {
            try {
                this._dbusImpl.unexport();
            } catch (e) {
                console.log(`DesktopControl: disable unexport failed: ${e}`);
            }
            this._dbusImpl = null;
        }
        console.log('DesktopControl extension disabled');
    }
}
