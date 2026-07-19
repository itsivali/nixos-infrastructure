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
  # Pinned Firefox extensions (hashes resolved from AMO latest xpi).
  mkAddon = name: url: sha256: pkgs.fetchFirefoxAddon { inherit name url sha256; };

  extensions = {
    # Force-install even if the AMO target Firefox version differs slightly.
    force = true;
    packages = [
      (mkAddon "ublock-origin" "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi" "40c315b0da7871868155ecfae7a50a58dfa0920aebd865e008214986f1b7c578")
      (mkAddon "bitwarden-password-manager" "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi" "7ba16c3d422ab287db17b014a4683bace36341e471e4d4fd58ac2b616c6ac17d")
      (mkAddon "darkreader" "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi" "f4f047fe08e420b6d29617738ea00a7b784892b2262b7e6f38dd09b8ee958a44")
      (mkAddon "sidebery" "https://addons.mozilla.org/firefox/downloads/latest/sidebery/latest.xpi" "e8a0a4b556ab7dd536897c1816af9d0918030223068ea6683a04376103a6caf2")
    ];
  };
in
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

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

        # ── Keep logins: reject 3rd-party only, keep 1st-party ────
        "network.cookie.cookieBehavior" = 1;
        "network.cookie.cookieBehavior.notify" = false;
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
          --gruvbox-bg: #282828;
          --gruvbox-fg: #ebdbb2;
          --gruvbox-orange: #fe8019;
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

      extensions = extensions;
    };
  };
}
