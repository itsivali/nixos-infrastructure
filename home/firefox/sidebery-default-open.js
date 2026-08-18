/*
 * Set Sidebery as the default sidebar panel.
 *
 * Runs once per browser window (injected by the autoconfig loader in
 * home/firefox/default.nix). With expand-on-hover, the sidebar collapses
 * to a thin launcher rail; hovering the rail expands the full Sidebery
 * panel. This script ensures Sidebery is the *default* panel so it
 * appears when the user hovers the rail — without forcing the panel
 * open on startup (which would fight the collapsed state).
 *
 * Session restore / sidebar.backupState apply the window's UI state
 * asynchronously (updateUIState) and extension sidebars register
 * asynchronously too (startup cache). We poll briefly to:
 *  - If Sidebery is not the active command, switch to it.
 *  - Respect a different restored sidebar (e.g. bookmarks) and stop.
 *  - Stop once settled, so we don't fight the user afterwards.
 *
 * Notes:
 *  - No template literals or "${...}" here: the script is embedded into
 *    mozilla.cfg via builtins.toJSON (see default.nix).
 */
(() => {
  "use strict";
  if (window.__sideberyDefaultOpen) {
    return;
  }
  window.__sideberyDefaultOpen = true;

  const SIDEBERY_EXT_ID = "{3c078156-979c-498b-8990-85f7987dd929}";
  const ENSURE_INTERVAL_MS = 1000;
  const ENSURE_MAX_ATTEMPTS = 60;

  function findCommandID() {
    const ctrl = window.SidebarController;
    if (ctrl && ctrl.sidebars) {
      for (const [id, entry] of ctrl.sidebars) {
        if (entry && entry.extensionId === SIDEBERY_EXT_ID) {
          return id;
        }
      }
    }
    return null;
  }

  function ensureSideberyDefault() {
    const ctrl = window.SidebarController;
    if (!ctrl) {
      return;
    }
    let attempts = 0;
    const timer = setInterval(() => {
      attempts++;
      const id = findCommandID();
      if (!id) {
        // Sidebery's sidebar-action not registered yet (startup cache still
        // loading): keep polling until it is or the cap expires.
        if (attempts >= ENSURE_MAX_ATTEMPTS) {
          clearInterval(timer);
        }
        return;
      }
      let state = null;
      try {
        state = ctrl.getUIState();
      } catch (e) {}
      const cmd = state ? state.command : null;
      if (cmd && cmd !== id) {
        // A different sidebar was restored: respect it.
        clearInterval(timer);
        return;
      }
      // Sidebery is already the active command — done.
      if (cmd === id) {
        clearInterval(timer);
        return;
      }
      // Switch to Sidebery as the active panel (without forcing it open).
      // In expand-on-hover mode, the rail stays collapsed; the user will
      // see Sidebery when they hover the rail.
      if (!cmd && ctrl.setSidebarPanel) {
        try {
          ctrl.setSidebarPanel(id);
        } catch (e) {}
      }
      if (attempts >= ENSURE_MAX_ATTEMPTS) {
        clearInterval(timer);
      }
    }, ENSURE_INTERVAL_MS);
  }

  let attempts = 0;
  (function tick() {
    const ctrl = window.SidebarController;
    if (!ctrl && ++attempts <= 40) {
      setTimeout(tick, 250);
      return;
    }
    ensureSideberyDefault();
  })();
})();
