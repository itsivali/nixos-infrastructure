// workspaces.js — Workspace management for GNOME Shell 50
//
// Uses global.workspace_manager APIs directly.
// Provides queries, switching, and window-to-workspace operations.

import { log } from './logger.js';
import { matchWindow, currentTime } from './utils.js';

// ── Public API ────────────────────────────────────────────────────────────

/**
 * Get the current (active) workspace index.
 */
export function current() {
    return global.workspace_manager.get_active_workspace_index();
}

/**
 * Get the total number of workspaces.
 */
export function count() {
    return global.workspace_manager.get_n_workspaces();
}

/**
 * Switch to the workspace at the given index.
 * Returns true on success, false if the index is invalid.
 */
export function switchTo(index) {
    if (typeof index !== 'number' || !Number.isInteger(index))
        return false;

    const ws = global.workspace_manager.get_workspace_by_index(index);
    if (!ws)
        return false;

    try {
        ws.activate(currentTime());
        return true;
    } catch (e) {
        log.error(`switchTo failed: ${e.message}`);
        return false;
    }
}

/**
 * List all workspaces with metadata.
 * Returns a JSON string for D-Bus transport.
 */
export function list() {
    const total = count();
    const activeIndex = current();
    const result = [];

    for (let i = 0; i < total; i++) {
        const ws = global.workspace_manager.get_workspace_by_index(i);
        if (!ws)
            continue;

        result.push({
            index: i,
            active: i === activeIndex,
            n_windows: ws.list_windows().length,
            name: ws.get_name?.() || '',
        });
    }

    return JSON.stringify(result);
}

/**
 * Move a window matching the query to the workspace at targetIndex.
 */
export function moveWindowTo(query, targetIndex) {
    if (typeof targetIndex !== 'number' || !Number.isInteger(targetIndex))
        return false;

    const ws = global.workspace_manager.get_workspace_by_index(targetIndex);
    if (!ws)
        return false;

    // Find the matching window across all windows
    const allWindows = global.display.get_windows();
    for (const win of allWindows) {
        if (matchWindow(query, win)) {
            try {
                win.change_workspace_by_index(targetIndex, true);
                return true;
            } catch (e) {
                log.error(`moveWindowTo failed: ${e.message}`);
                return false;
            }
        }
    }

    return false;
}
