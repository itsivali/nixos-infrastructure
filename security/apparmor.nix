##############################################################################
#
# AppArmor
#
# Purpose
# -------
# AppArmor mandatory access control with custom profiles for
# infrastructure components.
#
# Ownership
# ---------
# security.apparmor
#
# Does NOT Own
# ------------
# - Sudo (security/sudo.nix)
# - System hardening (security/hardening.nix)
# - Fail2Ban (security/fail2ban.nix)
# - Packages (security/packages.nix)
#
# Profiles
# --------
# - ivali-bot: Telegram bot process (root, runs rebuilds/desktop automation)
# - ivali-cli: Go CLI binary (defined but NOT auto-attached; see note below)
# - gitops-reconciler: GitOps reconciliation service
#
# Enforcement
# -----------
# All profiles are enforced. Privileged subprocesses (nix/git/systemctl) run
# unconfined (ux) because they must write to /nix/store and use SSH keys.
#
# NOTE: ivali-cli is intentionally NOT attached to a path glob. Attaching it to
# /nix/store/**/bin/ivali would confine EVERY `ivali` invocation system-wide
# (shell, cron, bot, doctor) and break legitimate use. It is enforced only when
# a service explicitly sets AppArmorProfile = "ivali-cli".
##############################################################################

{ pkgs, lib, ... }:

let
  # Create profile derivations to avoid builtins.readFile Git tracking issues
  ivali-bot-profile = pkgs.writeText "ivali-bot" ''
    #include <tunables/global>

    profile ivali-bot /nix/store/*/bin/ivali-bot flags=(enforce) {
      #include <abstractions/base>
      #include <abstractions/nameservice>
      #include <abstractions/ssl_certs>
      #include <abstractions/dbus-session>

      # Bot runs as root and performs privileged ops; grant capabilities.
      capability,

      # Nix store: read + mmap-exec (Go runtime libs). No execute here.
      /nix/store/** rm,

      # Any Nix store binary may be executed, unconfined. The bot process
      # itself stays confined; its children (incl. nix/git/systemctl for
      # rebuilds) run unconfined so they can write /nix/store and use SSH
      # keys. AppArmor resolves execs to the real /nix/store target. A single
      # exec modifier (ux) is used everywhere to avoid conflicting x modifiers.
      /nix/store/*/bin/** ux,
      /run/current-system/sw/bin/** ux,
      /run/wrappers/bin/** ux,

      # System read-only access required by the Go runtime and helpers
      /etc/** r,
      /run/** r,

      # Repository (read/write — bot edits configs via /deploy)
      /home/ivali/nixos-infrastructure/** rw,

      # State directory (read/write)
      /var/lib/ivali-bot/ rw,
      /var/lib/ivali-bot/** rw,

      # SOPS secrets (read-only)
      /run/secrets/ r,
      /run/secrets/* r,

      # Network access
      network inet stream,
      network inet6 stream,
      network inet dgram,
      network unix stream,
      network unix dgram,

      # Device access (screenshot, brightness, audio, input)
      /dev/null rw,
      /dev/zero r,
      /dev/urandom r,
      /dev/input/** r,
      /dev/dri/** rw,

      # Proc and sys (read-only)
      /proc/ r,
      /proc/[0-9]*/ r,
      /proc/[0-9]*/** r,
      /proc/sys/kernel/hostname r,
      /proc/cpuinfo r,
      /proc/meminfo r,
      /proc/loadavg r,
      /proc/uptime r,
      /sys/ r,
      /sys/** r,

      # Temp files
      /tmp/ rw,
      /tmp/** rw,

      # Logs
      /var/log/ivali-bot/ rw,
      /var/log/ivali-bot/** rw,
      /var/log/** r,

      # Deny
      deny /etc/shadow r,
      deny /etc/passwd w,
      deny /root/** rw,
      deny /home/*/.ssh/** rw,
      deny /home/*/.gnupg/** rw,
    }
  '';

  ivali-cli-profile = pkgs.writeText "ivali-cli" ''
    #include <tunables/global>

    # No attachment glob: ivali-cli is enforced only when a service explicitly
    # sets AppArmorProfile = "ivali-cli". Attaching to /nix/store/**/bin/ivali
    # would confine every `ivali` invocation system-wide and break usage.
    profile ivali-cli flags=(enforce) {
      #include <abstractions/base>
      #include <abstractions/nameservice>

      # Nix store: read + mmap-exec. Store binaries exec unconfined.
      /nix/store/** rm,
      /nix/store/*/bin/** ux,
      /run/current-system/sw/bin/** ux,

      # Repository (read-only)
      /home/ivali/nixos-infrastructure/** r,

      # Device access
      /dev/null rw,
      /dev/zero r,
      /dev/urandom r,

      # Proc and sys (read-only)
      /proc/ r,
      /proc/[0-9]*/ r,
      /proc/[0-9]*/** r,
      /proc/cpuinfo r,
      /proc/meminfo r,
      /proc/loadavg r,
      /proc/uptime r,
      /sys/ r,
      /sys/** r,

      # Temp files
      /tmp/ r,
      /tmp/** rw,

      # Deny
      deny /etc/shadow r,
      deny /etc/passwd w,
      deny /root/** rw,
      deny /home/*/.ssh/** rw,
      deny /home/*/.gnupg/** rw,
    }
  '';

  gitops-reconciler-profile = pkgs.writeText "gitops-reconciler" ''
    #include <tunables/global>

    # No attachment glob: this profile is applied explicitly to the
    # gitops-reconciler systemd service via AppArmorProfile=. Attaching it to
    # /nix/store/**/bin/bash would enforce it on EVERY bash script on the
    # system (incl. boot/activation scripts) and break boot.
    profile gitops-reconciler flags=(enforce) {
      #include <abstractions/base>
      #include <abstractions/nameservice>

      capability,

      # Nix store: read + mmap-exec. Store binaries exec unconfined (so nix
      # can write /nix/store and git can use SSH keys for fetch+push).
      /nix/store/** rm,
      /nix/store/*/bin/** ux,
      /run/current-system/sw/bin/** ux,

      # Build workspace (the reconciler builds the ivali CLI here)
      /build/ rw,
      /build/** rw,

      # Repository (read/write — reconciles the flake)
      /home/ivali/nixos-infrastructure/ rw,
      /home/ivali/nixos-infrastructure/** rw,

      # Go build cache
      /home/ivali/go/ rw,
      /home/ivali/go/** rw,
      /root/go/ rw,
      /root/go/** rw,

      # GitOps worktree (read/write)
      /var/lib/gitops/ r,
      /var/lib/gitops/** rw,

      # State files
      /var/lib/gitops/.git/** rw,
      /tmp/deployment-health-last-ok rw,
      /tmp/** rw,

      # Broad runtime state
      /var/** rw,
      /run/** rw,

      # Device access
      /dev/null rw,
      /dev/zero r,
      /dev/urandom r,

      # Proc and sys (read-only)
      /proc/ r,
      /proc/[0-9]*/ r,
      /proc/[0-9]*/** r,
      /proc/sys/kernel/hostname r,
      /proc/cpuinfo r,
      /proc/meminfo r,
      /sys/ r,
      /sys/** r,

      # Network (for git fetch/push)
      network inet stream,
      network inet6 stream,
      network inet dgram,
      network unix stream,

      # Logs
      /var/log/ r,

      # Deny
      deny /home/*/.ssh/** rw,
      deny /home/*/.gnupg/** rw,
      deny /etc/shadow r,
    }
  '';
in
{
  security.apparmor = {
    enable = true;

    # Don't kill processes that are confined but not yet profiled
    killUnconfinedConfinables = false;

    packages = [
      pkgs.apparmor-profiles
      pkgs.apparmor-utils
      pkgs.apparmor-parser
    ];
  };

  # Install custom AppArmor profiles via policies
  security.apparmor.policies = {
    "ivali-bot" = {
      path = ivali-bot-profile;
      state = "enforce";
    };
    "ivali-cli" = {
      path = ivali-cli-profile;
      state = "enforce";
    };
    "gitops-reconciler" = {
      path = gitops-reconciler-profile;
      state = "enforce";
    };
  };
}
