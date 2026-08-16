/*
 * Sidebery flyout for the collapsed sidebar launcher rail.
 *
 * Runs once per browser window (injected by the autoconfig loader in
 * home/firefox/default.nix). While the native sidebar is in
 * "expand-on-hover" mode, hovering the collapsed rail opens the Sidebery
 * panel, and the panel closes again once the pointer leaves the rail or the
 * panel (grace period for the pointer crossing into the panel itself).
 *
 * Additionally, once the window's restored UI state settles (session
 * restore or the sidebar.backupState fallback), the Sidebery panel is
 * opened so the sidebar shows the tab tree by default instead of the
 * launcher rail's extension buttons. This makes "show tabs" the persistent
 * default across restarts and generations.
 *
 * Notes:
 *  - The Sidebery panel is rendered inside a remote <browser>, so the chrome
 *    window stops receiving mousemove events while the pointer is over the
 *    panel. This is why closing is event-driven from chrome mousemove
 *    (closes when the pointer re-enters chrome outside rail+panel) plus
 *    window-leave / window-blur fallbacks, instead of pure leave detection.
 *  - No template literals or "${...}" here: the script is embedded into
 *    mozilla.cfg via builtins.toJSON (see default.nix).
 */
(() => {
  "use strict";
  if (window.__sideberyFlyout) {
    return;
  }
  window.__sideberyFlyout = true;

  const SIDEBERY_EXT_ID = "{3c078156-979c-498b-8990-85f7987dd929}";
  const OPEN_DELAY_MS = 120;
  const CLOSE_GRACE_MS = 350;

  let openedByHover = false;
  let lastPointer = null;
  let openTimer = null;
  let closeTimer = null;

  function getRail() {
    return document.getElementById("sidebar-main");
  }

  function getPanelBox() {
    return document.getElementById("sidebar-box");
  }

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

  function inRect(x, y, r) {
    return x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
  }

  function overRail(x, y) {
    const el = getRail();
    return !!el && inRect(x, y, el.getBoundingClientRect());
  }

  function overPanel(x, y) {
    const el = getPanelBox();
    return !!el && !el.hidden && inRect(x, y, el.getBoundingClientRect());
  }

  function maybeOpen() {
    if (openedByHover) {
      return;
    }
    const ctrl = window.SidebarController;
    if (!ctrl || ctrl.isOpen) {
      return;
    }
    const id = findCommandID();
    if (!id) {
      return;
    }
    clearTimeout(openTimer);
    openTimer = setTimeout(() => {
      if (!lastPointer || !overRail(lastPointer.x, lastPointer.y)) {
        return;
      }
      if (!ctrl.isOpen) {
        openedByHover = true;
        try {
          ctrl.show(id);
        } catch (e) {
          openedByHover = false;
        }
      }
    }, OPEN_DELAY_MS);
  }

  function closeNow() {
    clearTimeout(closeTimer);
    const ctrl = window.SidebarController;
    if (!openedByHover || !ctrl || !ctrl.isOpen) {
      return;
    }
    openedByHover = false;
    try {
      ctrl.hide({ dismissPanel: false });
    } catch (e) {}
  }

  function scheduleClose() {
    clearTimeout(closeTimer);
    closeTimer = setTimeout(closeNow, CLOSE_GRACE_MS);
  }

  function onMouseMove(e) {
    lastPointer = { x: e.clientX, y: e.clientY };
    if (overRail(e.clientX, e.clientY)) {
      clearTimeout(closeTimer);
      maybeOpen();
    } else if (overPanel(e.clientX, e.clientY)) {
      clearTimeout(closeTimer);
    } else {
      scheduleClose();
    }
  }

  function onWindowLeave() {
    closeNow();
  }

  function onWindowBlur() {
    closeNow();
  }

  function onRailMouseDown() {
    // The user is taking manual control via the launcher buttons: stop the
    // hover-close behavior so the panel can be pinned open or toggled.
    openedByHover = false;
    clearTimeout(openTimer);
  }

  /*
   * Open Sidebery in the sidebar once the window's UI state has settled, so
   * the panel shows the tab tree instead of the launcher rail. Session
   * restore / backup state is applied asynchronously (updateUIState); wait
   * for it (capped) before deciding so we don't race it:
   *  - If another sidebar (e.g. bookmarks) was restored, leave it alone.
   *  - If the current command is Sidebery with the panel closed, open it.
   *  - If no command is set (fresh profile), open Sidebery as the default.
   */
  function ensureSideberyOpen() {
    const ctrl = window.SidebarController;
    const id = findCommandID();
    if (!ctrl || !id || ctrl.isOpen) {
      return;
    }
    let state = null;
    try {
      state = ctrl.getUIState();
    } catch (e) {}
    const cmd = state ? state.command : null;
    if (cmd && cmd !== id) {
      return;
    }
    try {
      ctrl.show(id);
    } catch (e) {}
  }

  function waitForSettledState() {
    let polls = 0;
    const settleTimer = setInterval(() => {
      const ctrl = window.SidebarController;
      if (!ctrl || ctrl.uiStateInitialized || ++polls > 16) {
        clearInterval(settleTimer);
        ensureSideberyOpen();
      }
    }, 500);
  }

  function init() {
    const ctrl = window.SidebarController;
    const rail = getRail();
    if (!ctrl || !rail || !getPanelBox()) {
      return false;
    }
    if (
      document.documentElement.getAttribute("sidebar-expand-on-hover") === null
    ) {
      return false;
    }
    window.addEventListener("mousemove", onMouseMove, true);
    document.documentElement.addEventListener("mouseleave", onWindowLeave);
    window.addEventListener("blur", onWindowBlur);
    rail.addEventListener("mousedown", onRailMouseDown, true);
    return true;
  }

  let attempts = 0;
  (function tick() {
    if (!init() && ++attempts <= 40) {
      setTimeout(tick, 250);
      return;
    }
    waitForSettledState();
  })();
})();
