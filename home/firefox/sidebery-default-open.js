/*
 * Open Sidebery in the sidebar by default.
 *
 * Runs once per browser window (injected by the autoconfig loader in
 * home/firefox/default.nix). With the native sidebar in "always-show" mode
 * and the launcher rail hidden, the Sidebery panel should be open showing
 * the tab tree. Session restore / sidebar.backupState apply the window's UI
 * state asynchronously (updateUIState) and extension sidebars register
 * asynchronously too (startup cache), so a single one-shot check races both.
 * Instead, poll for a bounded window:
 *  - If the current command is Sidebery (or none yet) with the panel
 *    closed, open it. Re-attempt while the panel is still closed, so a late
 *    restore that reapplies panelOpen:false self-heals.
 *  - Respect a different restored sidebar (e.g. bookmarks) and stop.
 *  - Stop once the panel is open and the UI state has initialized, so we
 *    don't fight the user afterwards.
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

  function ensureSideberyOpen() {
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
      if (!ctrl.isOpen) {
        try {
          ctrl.show(id);
        } catch (e) {}
      } else if (ctrl.uiStateInitialized) {
        // Panel open and UI state settled: done. Don't fight the user.
        clearInterval(timer);
        return;
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
    ensureSideberyOpen();
  })();
})();
