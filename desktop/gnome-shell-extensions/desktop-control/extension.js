// Desktop Control — GNOME Shell extension for Telegram bot
// Provides a D-Bus API for remote window/workspace/screenshot control.
// UUID: desktop-control@prague.ivali

const { GLib, Gio, Meta } = imports.gi;
const Main = imports.ui.main;
const Screenshot = imports.ui.screenshot;

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
    <method name="Screenshot">
      <arg type="s" name="filename" direction="in"/>
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

function _listWindows() {
  let wins = [];
  let actors = global.get_window_actors();
  for (let a of actors) {
    let w = a.meta_window;
    if (!w) continue;
    wins.push({
      title: w.get_title() || '',
      wm_class: w.get_wm_class() || '',
      pid: w.get_pid(),
      workspace: w.get_workspace() ? w.get_workspace().index() : -1,
      minimized: w.is_minimized()
    });
  }
  return JSON.stringify(wins);
}

function _focusWindow(title) {
  let actors = global.get_window_actors();
  let lower = title.toLowerCase();
  for (let a of actors) {
    let w = a.meta_window;
    if (!w) continue;
    let t = (w.get_title() || '').toLowerCase();
    let wm = (w.get_wm_class() || '').toLowerCase();
    if (t.includes(lower) || wm.includes(lower)) {
      w.activate(global.get_current_time());
      return true;
    }
  }
  return false;
}

function _closeWindow(title) {
  let actors = global.get_window_actors();
  let lower = title.toLowerCase();
  for (let a of actors) {
    let w = a.meta_window;
    if (!w) continue;
    let t = (w.get_title() || '').toLowerCase();
    let wm = (w.get_wm_class() || '').toLowerCase();
    if (t.includes(lower) || wm.includes(lower)) {
      w.delete(global.get_current_time());
      return true;
    }
  }
  return false;
}

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

function _screenshot(filename) {
  try {
    let conn = Gio.DBus.session;
    let result = conn.call_sync(
      'org.gnome.Shell.Screenshot',
      '/org/gnome/Shell/Screenshot',
      'org.gnome.Shell.Screenshot',
      'Screenshot',
      new GLib.Variant('(bbs)', [false, false, filename]),
      null,
      Gio.DBusCallFlags.NONE,
      -1,
      null
    );
    let [success, usedFile] = result.deep_unpack();
    return success;
  } catch (e) {
    log(`DesktopControl: Screenshot failed: ${e}`);
    return false;
  }
}

function _getRunningApps() {
  let apps = [];
  let appSys = Shell.AppSystem.get_default();
  let running = appSys.get_running();
  for (let app of running) {
    apps.push({
      id: app.get_id(),
      name: app.get_name(),
      wm_class: app.get_wm_class()
    });
  }
  return JSON.stringify(apps);
}

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
  Screenshot(params) {
    let [filename] = params;
    return [_screenshot(filename)];
  },
  GetRunningApps(params) {
    return [_getRunningApps()];
  }
};

function init() {
}

function enable() {
  let ifaceXml = DesktopControlIface;
  let info = Gio.DBusNodeInfo.new_for_xml(ifaceXml);
  _dbusImpl = Gio.DBusExportedObject.wrapJSObject(info.interfaces[0], DesktopControlImpl);
  _dbusId = _dbusImpl.export(Gio.DBus.session, OBJECT_PATH);
  log('DesktopControl extension enabled — D-Bus service registered');
}

function disable() {
  if (_dbusImpl && _dbusId) {
    _dbusImpl.unexport();
    _dbusImpl = null;
    _dbusId = null;
  }
  log('DesktopControl extension disabled');
}
