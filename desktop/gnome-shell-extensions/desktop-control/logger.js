// logger.js — Structured logging with consistent prefix
//
// Every log message is prefixed with [DesktopControl] for easy journal filtering.
// Uses console.* methods (GNOME 45+ standard). No deprecated log() alias.
//
// Usage:
//   import { log } from './logger.js';
//   log.info('extension enabled');

const PREFIX = '[DesktopControl]';

export const log = {
    debug(msg) {
        console.debug(`${PREFIX} ${msg}`);
    },

    info(msg) {
        console.log(`${PREFIX} ${msg}`);
    },

    warn(msg) {
        console.warn(`${PREFIX} ${msg}`);
    },

    error(msg) {
        console.error(`${PREFIX} ${msg}`);
    },
};
