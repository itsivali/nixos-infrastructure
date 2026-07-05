// windows.js — Window management for GNOME Shell 50
//
// Provides window enumeration, matching, and operations.
// Uses global.display.list_all_windows() (GNOME 50 — Meta.Display API).
//
// All public methods return structured results, never throw to callers.
// Window matching supports regex (/pattern/) and case-insensitive substring.

import Meta from 'gi://Meta';

import { log } from './logger.js';
import { matchWindow, currentTime } from './utils.js';

// ── Window enumeration ────────────────────────────────────────────────────

/**
 * Collect all managed windows from the display.
 * Filters out skip-taskbar windows and non-normal window types.
 *
 * @returns {Meta.Window[]}
 */
function getWindows() {
    const all = global.display.list_all_windows();
    const managed = [];

    for (const win of all) {
        // Only include normal windows (dialogs, splashes, etc. are excluded)
        if (win.get_window_type() !== Meta.WindowType.NORMAL)
            continue;

        managed.push(win);
    }

    return managed;
}

/**
 * Find a window matching the query string.
 * Returns the first match or null.
 *
 * @param {string} query — search pattern (regex or substring)
 * @returns {Meta.Window|null}
 */
function findWindow(query) {
    const windows = getWindows();
    for (const win of windows) {
        if (matchWindow(query, win))
            return win;
    }
    return null;
}

// ── Public API ────────────────────────────────────────────────────────────

/**
 * List all managed windows with metadata.
 * Returns a JSON string for D-Bus transport.
 */
export function listWindows() {
    const windows = getWindows();
    const result = [];

    for (const win of windows) {
        const ws = win.get_workspace();
        result.push({
            title: win.get_title() || '',
            wm_class: win.get_wm_class?.() || win.get_wmclass?.() || '',
            pid: win.get_pid(),
            workspace: ws ? ws.index() : -1,
            minimized: win.is_hidden(),
            focused: win.has_focus(),
            fullscreen: win.is_fullscreen(),
            x: win.get_frame_rect().x,
            y: win.get_frame_rect().y,
            width: win.get_frame_rect().width,
            height: win.get_frame_rect().height,
        });
    }

    return JSON.stringify(result);
}

/**
 * Activate (focus) a window matching the query.
 */
export function activateWindow(query) {
    const win = findWindow(query);
    if (!win)
        return false;

    try {
        win.activate(currentTime());
        return true;
    } catch (e) {
        log.error(`activateWindow failed: ${e.message}`);
        return false;
    }
}

/**
 * Close a window matching the query.
 */
export function closeWindow(query) {
    const win = findWindow(query);
    if (!win)
        return false;

    try {
        win.delete(currentTime());
        return true;
    } catch (e) {
        log.error(`closeWindow failed: ${e.message}`);
        return false;
    }
}

/**
 * Minimize a window matching the query.
 */
export function minimizeWindow(query) {
    const win = findWindow(query);
    if (!win)
        return false;

    try {
        if (!win.is_hidden())
            win.minimize();
        return true;
    } catch (e) {
        log.error(`minimizeWindow failed: ${e.message}`);
        return false;
    }
}

/**
 * Maximize a window matching the query.
 */
export function maximizeWindow(query) {
    const win = findWindow(query);
    if (!win)
        return false;

    try {
        if (!win.is_maximized())
            win.maximize(Meta.MaximizeFlags.BOTH);
        return true;
    } catch (e) {
        log.error(`maximizeWindow failed: ${e.message}`);
        return false;
    }
}

/**
 * Unminimize (restore) a window matching the query.
 */
export function unminimizeWindow(query) {
    const win = findWindow(query);
    if (!win)
        return false;

    try {
        if (win.is_hidden())
            win.unminimize();
        return true;
    } catch (e) {
        log.error(`unminimizeWindow failed: ${e.message}`);
        return false;
    }
}

/**
 * Move a window to the specified coordinates.
 */
export function moveWindow(query, x, y) {
    const win = findWindow(query);
    if (!win)
        return false;

    try {
        win.move_frame(true, x, y);
        return true;
    } catch (e) {
        log.error(`moveWindow failed: ${e.message}`);
        return false;
    }
}

/**
 * Resize a window to the specified dimensions.
 */
export function resizeWindow(query, width, height) {
    const win = findWindow(query);
    if (!win)
        return false;

    try {
        const rect = win.get_frame_rect();
        win.move_resize_frame(true, rect.x, rect.y, width, height);
        return true;
    } catch (e) {
        log.error(`resizeWindow failed: ${e.message}`);
        return false;
    }
}

/**
 * Make a window fullscreen.
 */
export function fullscreenWindow(query) {
    const win = findWindow(query);
    if (!win)
        return false;

    try {
        if (!win.is_fullscreen())
            win.make_fullscreen();
        return true;
    } catch (e) {
        log.error(`fullscreenWindow failed: ${e.message}`);
        return false;
    }
}

/**
 * Remove fullscreen from a window.
 */
export function unfullscreenWindow(query) {
    const win = findWindow(query);
    if (!win)
        return false;

    try {
        if (win.is_fullscreen())
            win.unmake_fullscreen();
        return true;
    } catch (e) {
        log.error(`unfullscreenWindow failed: ${e.message}`);
        return false;
    }
}
