##############################################################################
#
# Nix Daemon
#
# Purpose
# -------
# Nix daemon settings, experimental features, garbage collection,
# and auto-upgrade.
#
# Ownership
# ---------
# nixpkgs.config.allowUnfree, nix.settings, nix.gc, system.autoUpgrade
#
# Does NOT Own
# ------------
# - Flake registry (N/A)
#
##############################################################################

{ username, gitlabUrl, hostName, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # Repository-wide nixpkgs overlays (see lib/overlays/). Applied to the host's
  # package set so that anyio/apostrophe build on rebuild.
  nixpkgs.overlays = import ../lib/overlays;

  documentation.doc.enable = false;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # Deliberately false — see nix.optimise below. Enabling this makes the
      # daemon deduplicate inline on *every* store import: each file is
      # hashed as it is added, then hard-linked if a twin already exists.
      # That cost lands on the critical path of every build and every
      # substitution, and is brutal on a bootstrap that imports ~20 GiB.
      # The scheduled pass reclaims exactly the same space off the clock.
      auto-optimise-store = false;

      trusted-users = [ "root" username "gitlab-runner" ];
      substituters = [ "https://cache.nixos.org" ];
      warn-dirty = false;

      # Build settings. NOTE: no `timeout` is set on purpose — a low global
      # build timeout (e.g. 60s) kills any derivation that builds longer,
      # which on this 2-core CPU includes the local Go tools (ivali, bw-tui)
      # and makes `nixos-rebuild switch` fail nondeterministically. Nix's
      # default (0 = no timeout) is correct here.

      # ── Parallel downloads ──────────────────────────────────────────
      # Substitution is network-bound, not CPU-bound, so these are tuned
      # well above core count. A rebuild that pulls a few thousand paths
      # spends most of its wall-clock here, not building.
      #
      # Keep in sync with the defaults in scripts/install-fresh-nixos.sh
      # (--download-jobs / --http-connections), which applies the same
      # values during bootstrap, before this config is active.

      # Parallel substitution jobs: how many store paths are fetched at
      # once. Nix's default of 16 leaves the link idle on a fast line.
      max-substitution-jobs = 32;

      # HTTP connections held open to the substituters. Must comfortably
      # exceed max-substitution-jobs, since narinfo lookups also queue
      # here.
      http-connections = 50;

      # Nix's default is 1 MiB, which fills almost immediately when many
      # downloads land at once; a full buffer stalls every substitution
      # until the decompressor drains it ("download buffer is full").
      download-buffer-size = 268435456; # 256 MiB

      # Fail over to the next substituter quickly instead of waiting out
      # the 15s default on an unreachable cache.
      connect-timeout = 5;

      # Seconds a connection may transfer nothing before it is abandoned.
      # Kept at 30 deliberately: a stalled mirror is dropped and retried
      # quickly rather than holding one of the substitution slots open.
      # If a slow link starts producing spurious "stalled download" aborts
      # under the raised concurrency above, lower max-substitution-jobs
      # rather than raising this.
      stalled-download-timeout = 30;

      # Enable parallel builds for faster compilation
      max-jobs = "auto";
      cores = 0;

      # Use case-hack for faster evaluation on case-insensitive filesystems
      use-case-hack = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 5d";
    };

    # Store deduplication, moved off the build critical path that
    # auto-optimise-store sits on. `nix store optimise` does the same
    # hashing and hard-linking in one scheduled pass instead of once per
    # imported path, so rebuilds stay fast and the space is still reclaimed.
    #
    # Scheduled after the weekly GC (OnCalendar=weekly fires Mon 00:00):
    # collecting garbage first means there is less left to walk. Persistent
    # is set by the module, so a missed window runs after the next boot.
    optimise = {
      automatic = true;
      dates = [ "Mon 04:15" ];
    };
  };

  system.autoUpgrade = {
    enable = false;
    flake = "git+${gitlabUrl}#${hostName}";
    flags = [
      "--refresh"
      "--print-build-logs"
    ];
    dates = "04:30";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };
}
