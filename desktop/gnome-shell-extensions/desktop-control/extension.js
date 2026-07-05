// Desktop Control — GNOME Shell extension for Telegram bot
// Provides a D-Bus API for remote window/workspace control.
// UUID: desktop-control@prague.ivali
//
// NOTE: Shell is a global injected by GNOME Shell — do NOT import
// from imports.gi.Shell (removed in GNOME Shell 45+).

const { Gio, Meta } = imports.gi;

const BUS_NAME = 'org.gnome.Shell.Extensions.DesktopControl';
const OBJECT_PATH = '/org/gnome/Shell/Extensions/DesktopControl';
const IFACE = 'org.gnome.Shell.Extensions.DesktopControl';

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

let _dbusImpl = null;
let _dbusId = null;

// ── Window iteration (works across GNOME Shell versions) ──────────────────

function _getWindows() {
  // Mutter 45+ (GNOME 45+): global.display.get_windows()
  if (typeof global.display.get_windows === 'function') {
    return global.display.get_windows();
  }
  // Mutter 42-44 fallback
  if (typeof global.display.get_tab_list === 'function') {
    let tabList = Meta.TabList || {};
    return global.display.get_tab_list(tabList.NORMAL_ALL || 0, null);
  }
  // Mutter 40-42 fallback (deprecated, removed in 44)
  if (typeof global.get_window_actors === 'function') {
    return global.get_window_actors().map(a => a.meta_window);
  }
  log('DesktopControl: no window iteration method available');
  return [];
}

// ── Window listing ────────────────────────────────────────────────────────

function _listWindows() {
  let wins = [];
  try {
    let windows = _getWindows();
    for (let w of windows) {
      if (w.is_monitor) continue;
      wins.push({
        title: w.get_title() || '',
        wm_class: w.get_wm_class() || '',
        pid: w.get_pid(),
        workspace: w.get_workspace() ? w.get_workspace().index() : -1,
        minimized: w.is_minimized()
      });
    }
  } catch (e) {
    log(`DesktopControl: _listWindows failed: ${e}`);
  }
  return JSON.stringify(wins);
}

// ── Window focusing ───────────────────────────────────────────────────────

function _focusWindow(title) {
  try {
    let windows = _getWindows();
    let lower = title.toLowerCase();
    for (let w of windows) {
      if (w.is_monitor) continue;
      let t = (w.get_title() || '').toLowerCase();
      let wm = (w.get_wm_class() || '').toLowerCase();
      if (t.includes(lower) || wm.includes(lower)) {
        w.activate(global.get_current_time());
        return true;
      }
    }
  } catch (e) {
    log(`DesktopControl: _focusWindow failed: ${e}`);
  }
  return false;
}

// ── Window closing ────────────────────────────────────────────────────────

function _closeWindow(title) {
  try {
    let windows = _getWindows();
    let lower = title.toLowerCase();
    for (let w of windows) {
      if (w.is_monitor) continue;
      let t = (w.get_title() || '').toLowerCase();
      let wm = (w.get_wm_class() || '').toLowerCase();
      if (t.includes(lower) || wm.includes(lower)) {
        w.delete(global.get_current_time());
        return true;
      }
    }
  } catch (e) {
    log(`DesktopControl: _closeWindow failed: ${e}`);
  }
  return false;
}

// ── Workspace methods ─────────────────────────────────────────────────────

function _getActiveWorkspace() {
  return global.workspace_manager.get_active_workspace_index();
}

function _getWorkspaceCount() {
  return global.workspace_manager.get_n_workspaces();
}

function _switchWorkspace(index) {
  let ws = global.workspace_manager.get_workspace_by_index(index);
  if (!ws) return false;
  ws.activate(global.get_current_time());
  return true;
}

// ── Running apps ──────────────────────────────────────────────────────────

function _getRunningApps() {
  let apps = [];
  try {
    let appSys = Shell.AppSystem.get_default();
    let running = appSys.get_running();
    for (let app of running) {
      apps.push({
        id: app.get_id(),
        name: app.get_name(),
        wm_class: app.get_wm_class()
      });
    }
  } catch (e) {
    log(`DesktopControl: _getRunningApps failed: ${e}`);
  }
  return JSON.stringify(apps);
}

// ── D-Bus implementation ──────────────────────────────────────────────────

const DesktopControlImpl = {
  ListWindows(params) {
    return [_listWindows()];
  },
  FocusWindow(params) {
    let [title] = params;
    return [_focusWindow(title)];
  },
  CloseWindow(params) {
    let [title] = params;
    return [_closeWindow(title)];
  },
  GetActiveWorkspace(params) {
    return [_getActiveWorkspace()];
  },
  GetWorkspaceCount(params) {
    return [_getWorkspaceCount()];
  },
  SwitchWorkspace(params) {
    let [index] = params;
    return [_switchWorkspace(index)];
  },
  GetRunningApps(params) {
    return [_getRunningApps()];
  }
};

// ── Lifecycle ─────────────────────────────────────────────────────────────

function init() {
}

function enable() {
  try {
    let ifaceXml = DesktopControlIface;
    let info = Gio.DBusNodeInfo.new_for_xml(ifaceXml);
    _dbusImpl = Gio.DBusExportedObject.wrapJSObject(info.interfaces[0], DesktopControlImpl);
    _dbusId = _dbusImpl.export(Gio.DBus.session, OBJECT_PATH);
    log('DesktopControl extension enabled — D-Bus service registered');
  } catch (e) {
    log(`DesktopControl: enable failed: ${e}`);
  }
}

function disable() {
  if (_dbusImpl && _dbusId) {
    try {
      _dbusImpl.unexport();
    } catch (e) {
      log(`DesktopControl: disable unexport failed: ${e}`);
    }
    _dbusImpl = null;
    _dbusId = null;
  }
  log('DesktopControl extension disabled');
}
