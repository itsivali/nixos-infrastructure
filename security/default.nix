# security/default.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ./firewall.nix
    ./tailscale.nix
  ];

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

