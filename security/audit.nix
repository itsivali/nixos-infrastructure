##############################################################################
#
# Audit Logging
#
# Purpose
# -------
# Comprehensive system auditing via auditd. Logs privilege escalation,
# file access, systemd commands, and authentication events to journald
# for forwarding to Loki.
#
# Ownership
# ---------
# security.audit, systemd.services.auditd, environment.etc."audit/rules.d/"
#
# Dependencies
# ------------
# - auditd package (security/packages.nix)
# - journald (observability/journald.nix)
# - Alloy forwarding to Loki (observability/alloy.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.security;
in
{
  options.ivali.security.audit = {
    enable = lib.mkEnableOption "auditd system auditing";
  };

  config = lib.mkIf cfg.audit.enable {
    security.auditd.enable = true;
    security.audit.enable = true;

    security.audit.rules = [
      # ── Privilege escalation ────────────────────────────────────────────
      # On NixOS, binaries live in /run/current-system/sw/bin or /nix/store.
      # Watching the store path directly is fragile (changes every rebuild).
      # Instead, watch the stable system profile symlinks and use auid-based
      # syscall rules that fire regardless of binary location.
      "-w /etc/sudoers -p wa -k sudoers"
      "-w /etc/sudoers.d/ -p wa -k sudoers"

      # Identity changes — /etc/passwd, /etc/shadow, /etc/group are mutable
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/gshadow -p wa -k identity"

      # ── SSH configuration ──────────────────────────────────────────────
      # On NixOS, sshd_config is a symlink to the Nix store. Watch the
      # parent dir for host key changes and sshd_config modifications.
      "-w /etc/ssh/ -p wa -k ssh_config"

      # ── Systemd and NixOS configuration ────────────────────────────────
      # /etc/systemd is a symlink tree managed by NixOS; watch it for
      # unexpected changes.
      "-w /etc/systemd/ -p wa -k systemd_config"

      # ── GitOps state ──────────────────────────────────────────────────
      # The reconciler worktree at /var/lib/gitops is the single source of
      # truth. Watch it for unexpected modifications.
      "-w /var/lib/gitops/ -p wa -k gitops_config"

      # ── Cron ──────────────────────────────────────────────────────────
      "-w /etc/crontab -p wa -k cron"
      "-w /etc/cron.d/ -p wa -k cron"
      "-w /var/spool/cron/ -p wa -k cron"

      # ── Failed access attempts ────────────────────────────────────────
      "-a always,exit -F arch=b64 -S open -F exit=-EACCES -k access_denied"
      "-a always,exit -F arch=b64 -S open -F exit=-EPERM -k access_denied"

      # ── Privilege escalation via execve (uid 0 → non-root auid) ──────
      # Catch any process that gains root privileges, regardless of which
      # binary is executed. This is more robust than watching specific
      # binary paths that change on every NixOS rebuild.
      "-a always,exit -F arch=b64 -S execve -F euid=0 -F auid!=4294967295 -F auid!=0 -k privilege_escalation"

      # ── Kernel module loading ────────────────────────────────────────
      # Watch the system profile's modprobe symlink for changes, plus use
      # syscall-level audit for the init_module/finit_module syscalls.
      "-a always,exit -F arch=b64 -S init_module -S finit_module -k kernel_modules"
      "-a always,exit -F arch=b64 -S delete_module -k kernel_modules"
    ];
  };
}
