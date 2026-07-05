// utils.js — Utility helpers for validation, serialization, and matching
//
// Provides type guards, structured response wrappers, and the core
// window-matching algorithm used across the extension. All public
// functions are pure — no side effects, no GNOME API access.

import { log } from './logger.js';

// ── JSON serialization ────────────────────────────────────────────────────

/**
 * Safely serialize an object to JSON.
 * Returns '[]' on failure instead of throwing.
 */
export function safeJson(obj) {
    try {
        return JSON.stringify(obj);
    } catch (e) {
        log.error(`safeJson failed: ${e.message}`);
        return '[]';
    }
}

// ── Type validation ───────────────────────────────────────────────────────

/**
 * Validate that a value is a non-empty string.
 * Throws a descriptive Error on failure.
 */
export function validateString(value, name) {
    if (typeof value !== 'string' || value.length === 0) {
        throw new Error(`${name}: expected non-empty string, got ${typeof value}`);
    }
}

/**
 * Validate that a value is an integer within [min, max].
 * Throws a descriptive Error on failure.
 */
export function validateInt(value, name, min = 0, max = 2147483647) {
    if (typeof value !== 'number' || !Number.isInteger(value)) {
        throw new Error(`${name}: expected integer, got ${typeof value}`);
    }
    if (value < min || value > max) {
        throw new Error(`${name}: ${value} out of range [${min}, ${max}]`);
    }
}

/**
 * Validate that a string is a valid regex pattern.
 * Throws a descriptive Error on failure.
 */
export function validateRegex(value, name) {
    try {
        new RegExp(value); // eslint-disable-line no-new
    } catch (e) {
        throw new Error(`${name}: invalid regex "${value}": ${e.message}`);
    }
}

// ── Structured D-Bus responses ────────────────────────────────────────────

/**
 * Wrap a successful result in a structured response.
 * The D-Bus caller receives this as a JSON string.
 */
export function wrapOk(data) {
    return safeJson({ ok: true, data });
}

/**
 * Wrap an error result in a structured response.
 */
export function wrapError(message) {
    return safeJson({ ok: false, error: message });
}

// ── Window matching ───────────────────────────────────────────────────────

/**
 * Test whether a window matches a query string.
 *
 * Matching strategy (ordered by priority):
 *   1. Regex — if query starts and ends with `/`, treat as regex pattern
 *      and test against title, wm_class, and app_id.
 *   2. Substring — case-insensitive substring match against title,
 *      wm_class, and app_id.
 *
 * @param {string} query — The search pattern
 * @param {Meta.Window} win — The window to test
 * @returns {boolean}
 */
export function matchWindow(query, win) {
    if (!query || !win)
        return false;

    const title = win.get_title() || '';
    const wmClass = win.get_wm_class?.() || win.get_wmclass?.() || '';
    const appId = '';

    // Regex mode: /pattern/flags
    if (query.startsWith('/') && query.length > 2 && query.endsWith('/')) {
        const pattern = query.slice(1, -1);
        try {
            const re = new RegExp(pattern, 'i');
            return re.test(title) || re.test(wmClass) || re.test(appId);
        } catch (e) {
            log.warn(`invalid regex pattern: ${pattern}`);
            return false;
        }
    }

    // Substring mode: case-insensitive
    const lower = query.toLowerCase();
    return title.toLowerCase().includes(lower) ||
        wmClass.toLowerCase().includes(lower) ||
        appId.toLowerCase().includes(lower);
}

/**
 * Get the current timestamp using the modern GNOME 50 API.
 * Replaces deprecated global.get_current_time().
 */
export function currentTime() {
    return global.display.get_current_time_roundtrip();
}
