// desktop.js — High-level desktop controller facade
//
// Orchestrates windows.js, workspaces.js, and applications.js.
// No D-Bus code here. No GNOME API calls here — delegates only.
// This is the single entry point for all desktop operations.

import * as Windows from './windows.js';
import * as Workspaces from './workspaces.js';
import * as Apps from './applications.js';
import { wrapOk, wrapError } from './utils.js';

// ── Version ───────────────────────────────────────────────────────────────

const VERSION = '2.0.0';

// ── Public API ────────────────────────────────────────────────────────────
//
// Every method returns a JSON string suitable for D-Bus transport.
// Operations return structured responses: { ok: true/false, data?, error? }
// Queries return raw JSON arrays/objects.

export function ping() {
    return true;
}

export function version() {
    return VERSION;
}

// ── Windows ───────────────────────────────────────────────────────────────

export function listWindows() {
    try {
        return Windows.listWindows();
    } catch (e) {
        return wrapError(`listWindows: ${e.message}`);
    }
}

export function focusWindow(query) {
    try {
        const ok = Windows.activateWindow(query);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`focusWindow: ${e.message}`);
    }
}

export function closeWindow(query) {
    try {
        const ok = Windows.closeWindow(query);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`closeWindow: ${e.message}`);
    }
}

export function minimizeWindow(query) {
    try {
        const ok = Windows.minimizeWindow(query);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`minimizeWindow: ${e.message}`);
    }
}

export function maximizeWindow(query) {
    try {
        const ok = Windows.maximizeWindow(query);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`maximizeWindow: ${e.message}`);
    }
}

export function moveWindow(query, x, y) {
    try {
        const ok = Windows.moveWindow(query, x, y);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`moveWindow: ${e.message}`);
    }
}

export function resizeWindow(query, width, height) {
    try {
        const ok = Windows.resizeWindow(query, width, height);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`resizeWindow: ${e.message}`);
    }
}

export function fullscreenWindow(query) {
    try {
        const ok = Windows.fullscreenWindow(query);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`fullscreenWindow: ${e.message}`);
    }
}

export function unfullscreenWindow(query) {
    try {
        const ok = Windows.unfullscreenWindow(query);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`unfullscreenWindow: ${e.message}`);
    }
}

// ── Workspaces ────────────────────────────────────────────────────────────

export function currentWorkspace() {
    try {
        return Workspaces.current();
    } catch (e) {
        return -1;
    }
}

export function workspaceCount() {
    try {
        return Workspaces.count();
    } catch (e) {
        return 0;
    }
}

export function switchWorkspace(index) {
    try {
        const ok = Workspaces.switchTo(index);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`switchWorkspace: ${e.message}`);
    }
}

export function listWorkspaces() {
    try {
        return Workspaces.list();
    } catch (e) {
        return wrapError(`listWorkspaces: ${e.message}`);
    }
}

// ── Applications ──────────────────────────────────────────────────────────

export function runningApplications() {
    try {
        return Apps.running();
    } catch (e) {
        return wrapError(`runningApplications: ${e.message}`);
    }
}

export function launchApplication(applicationId) {
    try {
        const ok = Apps.launch(applicationId);
        return wrapOk(ok);
    } catch (e) {
        return wrapError(`launchApplication: ${e.message}`);
    }
}
