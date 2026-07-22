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
      # Monitor privilege escalation
      "-w /usr/bin/sudo -p x -k privilege_escalation"
      "-w /usr/bin/su -p x -k privilege_escalation"
      "-w /usr/bin/passwd -p x -k password_change"
      "-w /usr/bin/chsh -p x -k privilege_escalation"
      "-w /usr/bin/newgrp -p x -k privilege_escalation"
      "-w /usr/sbin/useradd -p x -k user_management"
      "-w /usr/sbin/userdel -p x -k user_management"
      "-w /usr/sbin/usermod -p x -k user_management"
      "-w /usr/sbin/groupadd -p x -k user_management"

      # Monitor SSH key and config changes
      "-w /etc/ssh/sshd_config -p wa -k ssh_config"
      "-w /root/.ssh/ -p wa -k ssh_keys"

      # Monitor NixOS configuration changes
      "-w /etc/nixos/ -p wa -k nixos_config"

      # Monitor system service changes
      "-w /etc/systemd/ -p wa -k systemd_config"

      # Monitor cron
      "-w /etc/crontab -p wa -k cron"
      "-w /etc/cron.d/ -p wa -k cron"
      "-w /var/spool/cron/ -p wa -k cron"

      # Failed access attempts
      "-a always,exit -F arch=b64 -S open -F exit=-EACCES -k access_denied"
      "-a always,exit -F arch=b64 -S open -F exit=-EPERM -k access_denied"

      # Monitor kernel module loading
      "-w /sbin/insmod -p x -k kernel_modules"
      "-w /sbin/rmmod -p x -k kernel_modules"
      "-w /sbin/modprobe -p x -k kernel_modules"
    ];
  };
}
