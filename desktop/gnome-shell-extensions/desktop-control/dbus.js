// dbus.js — D-Bus interface definition, export, and method dispatch
//
// Owns the complete D-Bus lifecycle:
//   - Interface XML definition (single source of truth)
//   - Gio.DBusExportedObject creation and export
//   - Input validation before dispatch
//   - Error handling and structured responses
//   - Clean unexport on teardown
//
// This module never touches GNOME Shell APIs directly.
// It delegates all operations to desktop.js.

import Gio from 'gi://Gio';

import { log } from './logger.js';
import {
    validateString,
    validateInt,
    safeJson,
} from './utils.js';
import * as Desktop from './desktop.js';

// ── Constants ─────────────────────────────────────────────────────────────

const IFACE_NAME = 'org.gnome.Shell.Extensions.DesktopControl';
const OBJECT_PATH = '/org/gnome/Shell/Extensions/DesktopControl';

// ── D-Bus Interface XML ───────────────────────────────────────────────────
//
// This is the canonical definition of the D-Bus interface.
// All method signatures, argument types, and names are declared here.

const IFACE_XML = `
<node>
  <interface name="${IFACE_NAME}">
    <!-- Health -->
    <method name="Ping">
      <arg type="b" name="alive" direction="out"/>
    </method>
    <method name="Version">
      <arg type="s" name="version" direction="out"/>
    </method>

    <!-- Windows -->
    <method name="ListWindows">
      <arg type="s" name="windows_json" direction="out"/>
    </method>
    <method name="FocusWindow">
      <arg type="s" name="query" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>
    <method name="CloseWindow">
      <arg type="s" name="query" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>
    <method name="MinimizeWindow">
      <arg type="s" name="query" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>
    <method name="MaximizeWindow">
      <arg type="s" name="query" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>
    <method name="MoveWindow">
      <arg type="s" name="query" direction="in"/>
      <arg type="i" name="x" direction="in"/>
      <arg type="i" name="y" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>
    <method name="ResizeWindow">
      <arg type="s" name="query" direction="in"/>
      <arg type="i" name="width" direction="in"/>
      <arg type="i" name="height" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>
    <method name="FullscreenWindow">
      <arg type="s" name="query" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>
    <method name="UnfullscreenWindow">
      <arg type="s" name="query" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>

    <!-- Workspaces -->
    <method name="CurrentWorkspace">
      <arg type="i" name="index" direction="out"/>
    </method>
    <method name="WorkspaceCount">
      <arg type="i" name="count" direction="out"/>
    </method>
    <method name="SwitchWorkspace">
      <arg type="i" name="index" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>
    <method name="ListWorkspaces">
      <arg type="s" name="workspaces_json" direction="out"/>
    </method>

    <!-- Applications -->
    <method name="RunningApplications">
      <arg type="s" name="apps_json" direction="out"/>
    </method>
    <method name="LaunchApplication">
      <arg type="s" name="application_id" direction="in"/>
      <arg type="s" name="result_json" direction="out"/>
    </method>
  </interface>
</node>
`;

// ── Service Implementation ────────────────────────────────────────────────
//
// This class implements the D-Bus interface methods.
// Gio.DBusExportedObject.wrapJSObject() expects a plain object/class
// with methods matching the D-Bus interface definition.
//
// Input validation happens here. Dispatch to desktop.js happens here.
// No GNOME APIs are called directly.

class DesktopControlService {
    // ── Health ────────────────────────────────────────────────────────

    Ping() {
        return Desktop.ping();
    }

    Version() {
        return Desktop.version();
    }

    // ── Windows ───────────────────────────────────────────────────────

    ListWindows() {
        return Desktop.listWindows();
    }

    FocusWindow(query) {
        try {
            validateString(query, 'query');
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.focusWindow(query);
    }

    CloseWindow(query) {
        try {
            validateString(query, 'query');
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.closeWindow(query);
    }

    MinimizeWindow(query) {
        try {
            validateString(query, 'query');
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.minimizeWindow(query);
    }

    MaximizeWindow(query) {
        try {
            validateString(query, 'query');
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.maximizeWindow(query);
    }

    MoveWindow(query, x, y) {
        try {
            validateString(query, 'query');
            validateInt(x, 'x', -16384, 16384);
            validateInt(y, 'y', -16384, 16384);
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.moveWindow(query, x, y);
    }

    ResizeWindow(query, width, height) {
        try {
            validateString(query, 'query');
            validateInt(width, 'width', 1, 32768);
            validateInt(height, 'height', 1, 32768);
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.resizeWindow(query, width, height);
    }

    FullscreenWindow(query) {
        try {
            validateString(query, 'query');
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.fullscreenWindow(query);
    }

    UnfullscreenWindow(query) {
        try {
            validateString(query, 'query');
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.unfullscreenWindow(query);
    }

    // ── Workspaces ────────────────────────────────────────────────────

    CurrentWorkspace() {
        return Desktop.currentWorkspace();
    }

    WorkspaceCount() {
        return Desktop.workspaceCount();
    }

    SwitchWorkspace(index) {
        try {
            validateInt(index, 'index', 0, 64);
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.switchWorkspace(index);
    }

    ListWorkspaces() {
        return Desktop.listWorkspaces();
    }

    // ── Applications ──────────────────────────────────────────────────

    RunningApplications() {
        return Desktop.runningApplications();
    }

    LaunchApplication(applicationId) {
        try {
            validateString(applicationId, 'application_id');
        } catch (e) {
            return safeJson({ ok: false, error: e.message });
        }
        return Desktop.launchApplication(applicationId);
    }
}

// ── D-Bus Manager ─────────────────────────────────────────────────────────
//
// Manages the lifecycle of the D-Bus exported object.
// This is the public interface consumed by extension.js.

export class DesktopControlDbus {
    constructor() {
        this._impl = null;
        this._service = null;
        this._ownerId = 0;
    }

    /**
     * Export the D-Bus interface and own the bus name.
     *
     * Two steps are required:
     *   1. Export the object at the given path (makes the interface available)
     *   2. Own the well-known bus name (makes the service discoverable)
     *
     * Both must succeed for clients to find us.
     */
    export() {
        try {
            const info = Gio.DBusNodeInfo.new_for_xml(IFACE_XML);
            this._service = new DesktopControlService();
            this._impl = Gio.DBusExportedObject.wrapJSObject(
                info.interfaces[0],
                this._service,
            );
            this._impl.export(Gio.DBus.session, OBJECT_PATH);

            // Own the well-known bus name so clients can discover us
            this._ownerId = Gio.bus_own_name(
                Gio.BusType.SESSION,
                IFACE_NAME,
                Gio.BusNameOwnerFlags.NONE,
                () => log.info('D-Bus name acquired'),
                () => log.info('D-Bus name acquired (secondary)'),
                (_conn, _name) => {
                    log.warn('D-Bus name lost — another owner may exist');
                    this._ownerId = 0;
                },
            );

            log.info('D-Bus service exported');
        } catch (e) {
            log.error(`D-Bus export failed: ${e.message}`);
            this._cleanup();
        }
    }

    /**
     * Unexport the D-Bus interface and release the bus name.
     */
    unexport() {
        this._cleanup();
    }

    /** Internal cleanup — safe to call multiple times. */
    _cleanup() {
        if (this._ownerId) {
            try {
                Gio.bus_unown_name(this._ownerId);
            } catch (e) {
                log.error(`bus_unown_name failed: ${e.message}`);
            }
            this._ownerId = 0;
        }
        if (this._impl) {
            try {
                this._impl.unexport();
                log.info('D-Bus service unexported');
            } catch (e) {
                log.error(`D-Bus unexport failed: ${e.message}`);
            }
            this._impl = null;
            this._service = null;
        }
    }
}
