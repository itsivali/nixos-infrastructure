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
#   * Profile stored on a dedicated btrfs subvolume (/home/ivali/.mozilla/
#     firefox/ivali) so logged-in sessions survive a reinstall.
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
    sidebery = mkAddon "sidebery" "https://addons.mozilla.org/firefox/downloads/latest/sidebery/latest.xpi" "e8a0a4b556ab7dd536897c1816af9d0918030223068ea6683a04376103a6caf2";
  };
in
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    # This Home Manager / nixpkgs combo defaults configPath to
    # ~/.config/mozilla/firefox, but the nixpkgs Firefox binary actually
    # stores its profiles under ~/.mozilla/firefox (where the firefox-ivali
    # subvolume is mounted). Override so HM-managed profiles.ini + the ivali
    # profile land where Firefox reads them.
    configPath = ".mozilla/firefox";

    profiles.ivali = {
      # Lives on a dedicated btrfs subvolume (see hosts/prague/
      # hardware-configuration.nix) so cookies/logins survive a reinstall.
      # Path is RELATIVE to ~/.mozilla/firefox: Home Manager writes this as
      # `Path=ivali` with `IsRelative=1` (valid), and drops profile files into
      # the mounted subvolume. An absolute path here breaks both.
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
        # signedInUser.json for the Firefox Account, cache2) lives on the
        # persistent firefox-ivali subvolume, so site sessions AND the Firefox
        # Account sign-in survive a full reinstall. Do NOT sanitize on shutdown.
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
      };

      # Compact, Gruvbox-dark UI. Pairs with Sidebery (vertical tabs):
      # the horizontal tab strip is hidden.
      userChrome = ''
        /* Gruvbox-dark compact Firefox */
        :root {
          --gruvbox-bg: ${t.bg};
          --gruvbox-fg: ${t.fg};
          --gruvbox-orange: ${t.orange};
        }

        /* Hide the horizontal tab strip (Sidebery provides vertical tabs) */
        #TabsToolbar {
          visibility: collapse;
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
          background: #32302f !important;
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
      '';
    };
  };

  # Install extensions directly into the persistent ivali profile. Each xpi is
  # named by its gecko id ("nixos@<name>"), which is what Firefox expects in
  # <profile>/extensions/. extensions.autoDisableScopes=0 (above) keeps them
  # enabled on first launch.
  home.file = lib.mkMerge (lib.mapAttrsToList
    (n: a: {
      ".mozilla/firefox/ivali/extensions/${a.id}.xpi" = {
        source = "${a.pkg}/${a.id}.xpi";
        force = true;
      };
    })
    addons);
}
