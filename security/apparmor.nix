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
#
# NOTE: DevOps tools (kubectl, helm, terraform, ansible, etc.) are NOT
# confined because they run interactively and need broad filesystem/network
# access. AppConfining them would break legitimate workflows. If you need
# to confine a CI/CD pipeline, create a dedicated service with its own profile.
#
# NOTE: the gitops-reconciler service runs UNCONFINED (see
# automation/gitops-reconciler.nix) — confining bash broke the deploy loop
# (shared-lib exec-mmap denied), so AppArmor confinement is not applied there.
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

{ pkgs, lib, config, ... }:

let
  cfg = config.ivali.security.apparmor;
  repoPath = config.ivali.ssh.repoPath or "/home/ivali/nixos-infrastructure";
  userName = config.users.users.ivali.name or "ivali";

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
      ${repoPath}/** rw,

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
      # Read-only to the operator's deploy key + known_hosts so the bot
      # can run `git` as the user (sudo -u ivali). All other
      # writes under .ssh/.gnupg stay denied.
      owner /home/${userName}/.ssh/id_ed25519 r,
      owner /home/${userName}/.ssh/known_hosts r,
      deny /home/*/.ssh/** w,
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
      ${repoPath}/** r,

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
  };

  # The stock NixOS AppArmor ExecReload also runs `aa-remove-unknown`, which
  # fails on this system: apparmor-utils 5.0.0 expects rc.apparmor.functions
  # under apparmor-parser 5.0.0, but that file is only shipped by 4.1.7 (a
  # Nixpkgs packaging mismatch). The failing step marked every reload as
  # failed, so `nixos-rebuild switch` reported "Failed to reload apparmor".
  # Our profiles are static, so stale-profile removal is unnecessary; reload
  # only the enabled profile files.
  systemd.services.apparmor.serviceConfig.ExecReload = lib.mkForce [
    "${pkgs.apparmor-parser}/bin/apparmor_parser --replace --verbose --show-cache ${ivali-bot-profile}"
    "${pkgs.apparmor-parser}/bin/apparmor_parser --replace --verbose --show-cache ${ivali-cli-profile}"
  ];
}
