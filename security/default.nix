# security/default.nix
#
# System hardening: AppArmor, polkit, PAM, fail2ban, audit.
# Auto-discovers sibling modules — no manual import list to maintain.
#
# Current auto-discovered modules:
#   firewall.nix   ← nftables, port policy, Tailscale WireGuard port
#   tailscale.nix  ← ivali.tailscale option + split-DNS timer
#
# Examples of what you can drop here:
#   yubikey.nix    — PAM U2F / FIDO2 configuration
#   hardening.nix  — kernel lockdown, sysctl hardening extras
#   aide.nix       — AIDE file-integrity monitoring cron
{ config, lib, pkgs, ... }:
{
  # firewall.nix and tailscale.nix are auto-discovered here.
  imports = import ../lib/auto-imports.nix ./.;

  security = {
    sudo.execWheelOnly = true;
    protectKernelImage = true;
    rtkit.enable = true;

    polkit = {
      enable = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
          return polkit.Result.AUTH_ADMIN;
        });
      '';
    };

    apparmor = {
      enable = true;
      killUnconfinedConfinables = false;
      packages = [ pkgs.apparmor-profiles ];
    };

    # Audit rules — file-watch only, no execve catch-all.
    # The execve rules + -e 2 (immutable mode) were causing two problems:
    audit.enable = false;
    auditd.enable = false;

    pam = {
      services.login.fprintAuth = false;
      loginLimits = [
        {
          domain = "*";
          type = "hard";
          item = "maxlogins";
          value = "10";
        }
      ];
    };
  };

  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    ignoreIP = [
      "127.0.0.0/8"
      "::1"
    ];
    bantime-increment = {
      enable = true;
      multipliers = "2 4 8 16 32 64 128 256 512 1024";
      maxtime = "168h";
      overalljails = true;
    };
    jails.sshd.settings = {
      enabled = true;
      filter = "sshd";
      port = "ssh";
      maxretry = 3;
      findtime = "10m";
      bantime = "1h";
      backend = "%(sshd_backend)s";
      logpath = "%(sshd_log)s";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/log/audit 0750 root root -"
  ];

  environment.systemPackages = with pkgs; [
    aide
    audit
    lynis
  ];
}
