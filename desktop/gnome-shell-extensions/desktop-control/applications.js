// applications.js — Application management for GNOME Shell 50
//
// Uses Shell.AppSystem for application queries and lifecycle.
// Provides running-app enumeration, launch, activate, and quit.

import Shell from 'gi://Shell';

import { log } from './logger.js';

// ── Helpers ───────────────────────────────────────────────────────────────

function appSystem() {
    return Shell.AppSystem.get_default();
}

// ── Public API ────────────────────────────────────────────────────────────

/**
 * List all running applications.
 * Returns a JSON string for D-Bus transport.
 */
export function running() {
    const apps = appSystem().get_running();
    const result = [];

    for (const app of apps) {
        result.push({
            id: app.get_id() || '',
            name: app.get_name() || '',
            wm_class: app.get_id().replace('.desktop', '').split('.').pop() || '',
            pids: app.get_pids() || [],
        });
    }

    return JSON.stringify(result);
}

/**
 * Launch an application by its desktop application ID.
 * Example: "org.mozilla.firefox.desktop"
 *
 * Returns true on success, false if the app is not found.
 */
export function launch(applicationId) {
    const app = appSystem().lookup_app(applicationId);
    if (!app)
        return false;

    try {
        app.open_new_window(-1);
        return true;
    } catch (e) {
        log.error(`launch failed for ${applicationId}: ${e.message}`);
        return false;
    }
}

/**
 * Activate (focus) a running application by its ID.
 */
export function activate(applicationId) {
    const app = appSystem().lookup_app(applicationId);
    if (!app)
        return false;

    try {
        app.activate();
        return true;
    } catch (e) {
        log.error(`activate failed for ${applicationId}: ${e.message}`);
        return false;
    }
}

/**
 * Quit a running application by its ID.
 */
export function quit(applicationId) {
    const app = appSystem().lookup_app(applicationId);
    if (!app)
        return false;

    try {
        app.request_quit();
        return true;
    } catch (e) {
        log.error(`quit failed for ${applicationId}: ${e.message}`);
        return false;
    }
}

/**
 * Get metadata for a running application by its ID.
 * Returns a JSON string with app info, or null if not found.
 */
export function metadata(applicationId) {
    const app = appSystem().lookup_app(applicationId);
    if (!app)
        return null;

    return JSON.stringify({
        id: app.get_id() || '',
        name: app.get_name() || '',
        description: app.get_description() || '',
        wm_class: app.get_id().replace('.desktop', '').split('.').pop() || '',
        icon: app.get_icon_name?.() || '',
        n_windows: app.get_n_windows(),
    });
}
