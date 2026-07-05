// extension.js — GNOME Shell extension lifecycle
//
// This file contains ONLY lifecycle management:
//   enable()  — start the D-Bus service
//   disable() — stop the D-Bus service
//
// No business logic. No GNOME API calls. No D-Bus XML.
// All functionality is delegated to dbus.js → desktop.js → domain modules.

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import { DesktopControlDbus } from './dbus.js';
import { log } from './logger.js';

export default class DesktopControlExtension extends Extension {
    enable() {
        log.info('enabling extension');
        this._dbus = new DesktopControlDbus();
        this._dbus.export();
    }

    disable() {
        log.info('disabling extension');
        this._dbus?.unexport();
        this._dbus = null;
    }
}
