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
# - ivali-bot: Telegram bot process
# - ivali-cli: Go CLI binary
# - gitops-reconciler: GitOps reconciliation service
#
# All profiles start in complain mode for safe deployment.
# To enforce a profile after validation:
#   aa-enforce /etc/apparmor.d/<profile>
#
##############################################################################

{ pkgs, lib, ... }:

let
  # Create profile derivations to avoid builtins.readFile Git tracking issues
  ivali-bot-profile = pkgs.writeText "ivali-bot" ''
    #include <tunables/global>

    profile ivali-bot /run/current-system/sw/bin/bash flags=(complain) {
      #include <abstractions/base>
      #include <abstractions/nameservice>
      #include <abstractions/ssl_certs>

      # Bot entrypoint and core scripts
      /run/current-system/sw/bin/bash r,
      /nix/store/** r,

      # Repository (read-only)
      /home/ivali/nixos-infrastructure/** r,

      # State directory (read/write)
      /var/lib/ivali-bot/ rw,
      /var/lib/ivali-bot/** rw,

      # SOPS secrets (read-only)
      /run/secrets/ r,
      /run/secrets/* r,

      # NixOS commands (execute)
      /run/current-system/sw/bin/nixos-rebuild ix,
      /run/current-system/sw/bin/nix ix,
      /run/current-system/sw/bin/systemctl ix,
      /run/current-system/sw/bin/git ix,

      # Core utilities (execute)
      /run/current-system/sw/bin/{bash,sh,coreutils,findutils,grep,sed,awk,curl,jq,timeout} ix,

      # Network access
      network inet stream,
      network inet6 stream,
      network inet dgram,
      network unix stream,

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

    profile ivali-cli /nix/store/**/bin/ivali flags=(complain) {
      #include <abstractions/base>
      #include <abstractions/nameservice>

      # Binary itself (read-only)
      /nix/store/** r,

      # Repository (read-only)
      /home/ivali/nixos-infrastructure/** r,

      # Nix commands (execute)
      /run/current-system/sw/bin/nix ix,
      /run/current-system/sw/bin/nix-env ix,
      /run/current-system/sw/bin/nixos-rebuild ix,

      # Core utilities (execute)
      /run/current-system/sw/bin/{bash,sh,coreutils,findutils,grep,sed,awk,git,stat,date,uname} ix,

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

    profile gitops-reconciler /nix/store/**/bin/bash flags=(complain) {
      #include <abstractions/base>
      #include <abstractions/nameservice>

      # Bash and Nix store
      /nix/store/** r,
      /run/current-system/sw/bin/bash ix,

      # Git commands
      /run/current-system/sw/bin/git ix,

      # Nix commands
      /run/current-system/sw/bin/nix ix,
      /run/current-system/sw/bin/nix-env ix,
      /run/current-system/sw/bin/nixos-rebuild ix,

      # Core utilities
      /run/current-system/sw/bin/{coreutils,findutils,grep,sed,awk,systemctl,jq} ix,

      # Repository (read-only)
      /home/ivali/nixos-infrastructure/** r,

      # GitOps worktree (read/write)
      /var/lib/gitops/ r,
      /var/lib/gitops/** rw,

      # State files
      /var/lib/gitops/.git/** rw,
      /tmp/deployment-health-last-ok rw,

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
      deny /home/*/.config/** rw,
      deny /run/secrets/** rw,
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

  # Install custom AppArmor profiles via environment.etc
  environment.etc."apparmor.d/ivali-bot" = {
    source =ivali-bot-profile;
    mode = "0644";
  };

  environment.etc."apparmor.d/ivali-cli" = {
    source =ivali-cli-profile;
    mode = "0644";
  };

  environment.etc."apparmor.d/gitops-reconciler" = {
    source = gitops-reconciler-profile;
    mode = "0644";
  };
}
