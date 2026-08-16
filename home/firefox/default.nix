##############################################################################
#
# Firefox — Heavy Customization (privacy / perf / Gruvbox UI)
#
# Purpose
# -------
# Declarative Firefox managed by Home Manager:
#   * Arkenfox-lite privacy/telemetry hardening (logins preserved)
#   * Performance: Webrender + VAAPI + HTTP/3
#   * Gruvbox-dark, compact UI via userChrome.css
#   * Declarative extensions (uBlock Origin, Bitwarden, Dark Reader, Sidebery)
#   * Native collapsible sidebar (container) + Sidebery tab tree
#   * Profile lives as a plain directory (/home/ivali/.mozilla/firefox/ivali)
#     on the /home btrfs subvolume, so sessions persist across rebuilds.
#
# Ownership
# ---------
# programs.firefox (Home Manager)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox;
  t = theme.colors;

  # Hover-flyout for the collapsed launcher rail (see sidebery-flyout.js).
  #
  # Firefox's own "expand-on-hover" grows the rail to reveal the native pinned
  # tab grid, which userChrome.css hides — leaving an empty strip on hover. To
  # make hovering the rail open the Sidebery panel instead, a privileged
  # autoconfig bootstrap (mozilla.cfg) injects sidebery-flyout.js into every
  # browser window. Bootstrap mechanics rely on nixpkgs' firefox wrapper:
  #   * extraAutoConfig  -> appends a pref to <app>/defaults/pref/autoconfig.js,
  #                         which is what lets us disable the config sandbox so
  #                         mozilla.cfg runs with full chrome privileges.
  #   * extraPrefsFiles  -> appends the loader to <app>/mozilla.cfg, which the
  #                         autoconfig.js above tells Firefox to execute.
  # The per-window script is embedded as a JSON string literal so no extra
  # files or store-path coupling are needed.
  flyoutCfg = pkgs.writeText "mozilla.cfg" ''
    /* Sidebery hover-flyout loader. Runs once at startup in the privileged
       autoconfig scope (general.config.sandbox_enabled=false). It injects
       sidebery-flyout.js into every browser window so the script can reach
       window.SidebarController. */

    var SIDEBERY_FLYOUT_SCRIPT = ${builtins.toJSON (builtins.readFile ./sidebery-flyout.js)};

    /* Write the per-window script into the profile dir so the subscript
       loader can eval it (DOM script injection does not work in the XHTML
       browser chrome document). Returns its file:// URI or null. */
    function writeFlyoutScript() {
      try {
        var scriptFile = Services.dirsvc.get("ProfD", Ci.nsIFile);
        scriptFile.append("sidebery-flyout.js");
        var fout = Cc["@mozilla.org/network/file-output-stream;1"].createInstance(Ci.nsIFileOutputStream);
        fout.init(scriptFile, 0x02 | 0x08 | 0x20, 420, 0);
        fout.write(SIDEBERY_FLYOUT_SCRIPT, SIDEBERY_FLYOUT_SCRIPT.length);
        fout.close();
        return Services.io.newFileURI(scriptFile).spec;
      } catch (e) {
        Services.console.logStringMessage("sidebery-flyout write: " + e);
        return null;
      }
    }
    var SIDEBERY_FLYOUT_URI = writeFlyoutScript();
    var SIDEBERY_SCRIPTLOADER = Cc["@mozilla.org/moz/jssubscript-loader;1"].getService(Ci.mozIJSSubScriptLoader);

    function injectSideberyFlyout(win) {
      try {
        var doc = win && win.document;
        if (!doc || !doc.documentElement) {
          return;
        }
        if (doc.documentElement.getAttribute("windowtype") !== "navigator:browser") {
          return;
        }
        SIDEBERY_SCRIPTLOADER.loadSubScript(SIDEBERY_FLYOUT_URI, win);
      } catch (e) {
        Services.console.logStringMessage("sidebery-flyout: " + e);
      }
    }

    function sideberyFlyoutObserve(subject) {
      try {
        var win = subject && (subject.window || subject);
        if (win && win.document) {
          win.addEventListener(
            "load",
            function () {
              injectSideberyFlyout(win);
            },
            { once: true }
          );
          if (win.document.readyState === "complete") {
            injectSideberyFlyout(win);
          }
        }
      } catch (e) {
        Services.console.logStringMessage("sidebery-flyout: " + e);
      }
    }
    Services.obs.addObserver(
      sideberyFlyoutObserve,
      "chrome-document-global-created",
      false
    );

    /* Windows that already exist when this config runs (normally none). */
    var existingWindows = Services.wm.getEnumerator("navigator:browser");
    while (existingWindows.hasMoreElements()) {
      injectSideberyFlyout(existingWindows.getNext());
    }
  '';

  # Pinned Firefox extensions (hashes resolved from AMO latest xpi).
  #
  # nixpkgs' fetchFirefoxAddon emits a single <id>.xpi at the package root
  # (id == "nixos@<name>", also baked into the addon's gecko id). HM's
  # programs.firefox.extensions.packages expects a
  # share/mozilla/extensions/{uuid}/ layout this nixpkgs no longer produces,
  # so we install each xpi directly into the profile's extensions/ dir
  # (Firefox loads any <id>.xpi whose name matches the addon's gecko id).
  mkAddon = name: url: sha256:
    let pkg = pkgs.fetchFirefoxAddon { inherit name url sha256; };
    in { inherit pkg; id = pkg.extid; };

  addons = {
    ublock-origin = mkAddon "ublock-origin" "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi" "bccc51a773150af4af6e1fd62c7bfdeb7238b79ff2381b998fa9f2e38f64786a";
    bitwarden-password-manager = mkAddon "bitwarden-password-manager" "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi" "11836eb9d2abc9914bb337b57e20c5a09cf44f24fa572f7e886384fd350a5112";
    darkreader = mkAddon "darkreader" "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi" "f4f047fe08e420b6d29617738ea00a7b784892b2262b7e6f38dd09b8ee958a44";
    sidebery = mkAddon "sidebery" "https://addons.mozilla.org/firefox/downloads/latest/sidebery/latest.xpi" "1wnalq1n2dq479lad3h64c106609knpic63wi4vdazdbasss9878";
  };
in
{
  programs.firefox = {
    enable = true;
    # Override the stock wrapper so autoconfig can run our chrome bootstrap:
    # mozilla.cfg (flyoutCfg above) gets injected into every browser window,
    # and the config sandbox is disabled so that loader has full privileges.
    package = (pkgs.firefox.override {
      extraPrefsFiles = [ flyoutCfg ];
      extraAutoConfig = ''
        pref("general.config.sandbox_enabled", false);
      '';
    });

    # This Home Manager / nixpkgs combo defaults configPath to
    # ~/.config/mozilla/firefox, but the nixpkgs Firefox binary actually
    # stores its profiles under ~/.mozilla/firefox. Override so HM-managed
    # profiles.ini + the ivali profile land where Firefox reads them.
    configPath = ".mozilla/firefox";

    profiles.ivali = {
      # Plain directory under ~/.mozilla/firefox on the /home subvolume.
      # Path is RELATIVE to ~/.mozilla/firefox: Home Manager writes this as
      # `Path=ivali` with `IsRelative=1` (valid), and drops profile files
      # there. An absolute path here breaks both.
      path = "ivali";

      settings = {
        # ── Privacy / telemetry off (Arkenfox-lite) ──────────────
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unifiedIsArtifact" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "browser.shell.checkDefaultBrowser" = false;

        # Auto-enable declarative extensions (uBlock, Bitwarden, Dark Reader,
        # Sidebery) instead of leaving them installed-but-disabled.
        "extensions.autoDisableScopes" = 0;

        "browser.pocket.enabled" = false;
        "extensions.pocket.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        "browser.newtabpage.activity-stream.feeds.systemtopstories" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "beacon.enabled" = false;
        "browser.send_pings" = false;

        # ── Keep logins + sessions: reject 3rd-party only, keep 1st-party ─
        # The whole `ivali` profile (cookies, key4.db, logins.json,
        # signedInUser.json for the Firefox Account, cache2) lives as a plain
        # directory on the /home subvolume, so site sessions and the Firefox
        # Account sign-in persist across rebuilds. Do NOT sanitize on shutdown.
        "network.cookie.cookieBehavior" = 1;
        "network.cookie.cookieBehavior.notify" = false;
        "network.cookie.lifetimePolicy" = 0;
        "privacy.sanitize.sanitizeOnShutdown" = false;
        "signon.rememberSignons" = true;
        "signon.management.overlay.enabled" = true;

        # ── Performance ──────────────────────────────────────────
        "layers.acceleration.force-enabled" = true;
        "gfx.webrender.all" = true;
        "media.ffmpeg.vaapi.enabled" = true;
        "media.av1.enabled" = true;
        "network.http.http3.enabled" = true;
        "dom.ipc.processCount" = 8;
        "browser.sessionstore.interval" = 15000;
        "javascript.options.wasm_gc" = true;

        # ── Audio / WebRTC ──────────────────────────────────────
        # Prevents audio suspension during video calls (Google Meet)
        "media.audio.suspend_on_video_visibility.enabled" = false;
        # Enable screen sharing via the xdg-desktop-portal (Wayland)
        "media.getusermedia.screensharing.enabled" = true;
        # WebRTC for video/audio calls
        "media.webrtc.enabled" = true;
        "media.peerconnection.enabled" = true;
        "media.peerconnection.ice.default_address_only" = false;
        "media.peerconnection.ice.proxy_only" = false;
        "media.peerconnection.ice.no_host" = false;
        # Hardware H.264 encode for Meet/Zoom via VA-API where available
        "media.webrtc.hw.h264.enabled" = true;
        # Hardware VP8/VP9 decode for WebRTC (Google Meet uses VP8/VP9).
        # media.webrtc.mediadatadecoder_vpx_enabled is the current pref;
        # media.navigator.mediadatadecoder_vpx_enabled is the legacy name
        # still read by older profiles.
        "media.webrtc.mediadatadecoder_vpx_enabled" = true;
        "media.navigator.mediadatadecoder_vpx_enabled" = true;
        # DMABUF / VA-API accelerated video decode on Wayland
        "widget.dmabuf.force-enabled" = true;
        "media.hardware-video-decoding.enabled" = true;
        # Allow device permission prompts (mic, camera). The browser cannot
        # grant the permission itself: the first use of Meet/zoom prompts
        # once for mic + once for camera, and GNOME re-prompts via the
        # portal. This cannot be pre-approved declaratively.
        "media.navigator.permission.device" = true;
        # Autoplay policy: block with exception for media
        "media.autoplay.default" = 5;
        # DRM (Widevine) for streaming services
        "media.eme.enabled" = true;

        # ── UI / appearance (Gruvbox-dark, compact) ──────────────
        "ui.systemUsesDarkTheme" = 1;
        "browser.theme.toolbar-theme" = 1;
        "browser.uidensity" = 1;
        "browser.urlbar.quicksuggest.enabled" = false;
        "browser.urlbar.suggest.quicksuggest" = false;
        "browser.urlbar.suggest.weather" = false;
        "browser.startup.homepage" = "about:home";

        # ── Native sidebar as container + Sidebery tab tree ────────
        # sidebar.revamp enables the modern native sidebar; it hosts Sidebery,
        # which owns the actual tab strip. verticalTabs must be ON: Firefox's
        # SidebarManager forces sidebar.visibility to "hide-sidebar" whenever
        # verticalTabs is false, which would hide the whole revamped sidebar
        # (and with it Sidebery). With verticalTabs=true the native tab strip
        # is merely relocated into the sidebar, where userChrome.css hides it
        # (see below), so only Sidebery's tree is visible. expand-on-hover
        # collapses the sidebar to a slim launcher rail; userChrome.css keeps
        # the rail at its collapsed width, and sidebery-flyout.js makes
        # hovering the rail open the Sidebery panel (see sidebery-flyout.js).
        "sidebar.revamp" = true;
        "sidebar.verticalTabs" = true;
        "sidebar.visibility" = "expand-on-hover";
        # Snappier expand/collapse of the icon rail (default is slow)
        "sidebar.animation.expand-on-hover.duration-ms" = 50;
      };

      # Compact, Gruvbox-dark UI. The native sidebar hosts Sidebery (tab
      # tree); Firefox hides its own horizontal strip when the sidebar tab
      # tree is active.
      userChrome = ''
        /* Gruvbox-dark compact Firefox */
        :root {
          --gruvbox-bg: ${t.bg};
          --gruvbox-fg: ${t.fg};
          --gruvbox-orange: ${t.orange};
          --gruvbox-bgSoft: ${t.bgSoft};
        }

        /* Slim, dark urlbar / menus */
        #nav-bar {
          background: var(--gruvbox-bg) !important;
          border-bottom: 1px solid var(--gruvbox-orange) !important;
        }

        #urlbar,
        #searchbar {
          font-family: "JetBrains Mono" !important;
        }

        #urlbar-background {
          background: var(--gruvbox-bgSoft) !important;
          border: 1px solid var(--gruvbox-orange) !important;
        }

        menupopup,
        panel {
          background: var(--gruvbox-bg) !important;
          color: var(--gruvbox-fg) !important;
        }

        /* Compact findbar */
        findbar {
          background: var(--gruvbox-bg) !important;
          color: var(--gruvbox-fg) !important;
        }

        /* Sidebery is the tab tree: hide the native vertical tab list that
         * Firefox relocates into the sidebar when sidebar.verticalTabs=true.
         * The launcher rail (icon buttons) stays, so expand-on-hover still
         * collapses the sidebar to a slim strip. */
        #vertical-tabs {
          display: none !important;
        }

        /* Hover-flyout for the launcher rail (sidebery-flyout.js opens the
         * Sidebery panel instead). Lock the rail to its collapsed width so
         * the native expand-on-hover growth does not reveal the empty strip
         * where the (hidden) native tab grid would be. */
        :root[sidebar-expand-on-hover] #sidebar-main[sidebar-launcher-expanded],
        :root[sidebar-expand-on-hover] #sidebar-main[sidebar-ongoing-animations]:not([sidebar-launcher-expanded]) {
          width: var(--sidebar-launcher-collapsed-width, 51px) !important;
          min-width: var(--sidebar-launcher-collapsed-width, 51px) !important;
          max-width: var(--sidebar-launcher-collapsed-width, 51px) !important;
        }

        /* While the flyout panel is open, keep the rail's strip reserved so
         * the rail stays visible (and clickable) next to the panel. */
        :root[sidebar-expand-on-hover] #sidebar-box[sidebar-panel-open]:not([sidebar-positionend]) {
          margin-inline-start: var(--sidebar-launcher-collapsed-width, 51px) !important;
        }
        :root[sidebar-expand-on-hover] #sidebar-box[sidebar-panel-open][sidebar-positionend] {
          margin-inline-end: var(--sidebar-launcher-collapsed-width, 51px) !important;
        }
      '';
    };
  };

  # Install extensions directly into the ivali profile. Each xpi is
  # named by its gecko id ("nixos@<name>"), which is what Firefox expects in
  # <profile>/extensions/. extensions.autoDisableScopes=0 (above) keeps them
  # enabled on first launch. Sidebery's id is "nixos@sidebery" (the fetch
  # helper re-derives it from the xpi's install manifest).
  home.file = lib.mkMerge (lib.mapAttrsToList
    (n: a: {
      ".mozilla/firefox/ivali/extensions/${a.id}.xpi" = {
        source = "${a.pkg}/${a.id}.xpi";
        force = true;
      };
    })
    addons);
}
