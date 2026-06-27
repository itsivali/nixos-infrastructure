# security/default.nix
#
# System security, hardening and intrusion prevention.
#
# Auto-discovers sibling modules:
#   firewall.nix
#   tailscale.nix
#

{ config, lib, pkgs, ... }:

{
  imports = import ../lib/auto-imports.nix ./.;

  ##############################################################
  # Security
  ##############################################################

  security = {

    sudo = {
      enable = true;
      execWheelOnly = true;

      extraConfig = ''
        Defaults timestamp_timeout=5
        Defaults passwd_tries=3
        Defaults logfile="/var/log/sudo.log"
        Defaults use_pty
        Defaults insults
      '';
    };

    protectKernelImage = true;

    lockKernelModules = true;

    rtkit.enable = true;

    ############################################################
    # Polkit
    ############################################################

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

    ############################################################
    # AppArmor
    ############################################################

    apparmor = {
      enable = true;

      killUnconfinedConfinables = true;

      packages = [
        pkgs.apparmor-profiles
      ];
    };

    ############################################################
    # Audit
    ############################################################

    audit = {
      enable = false;
    };

    auditd = {
      enable = false;
    };

    ############################################################
    # PAM
    ############################################################

    pam = {

      services = {

        login = {
          fprintAuth = false;
        };

        sudo = {
          fprintAuth = false;
        };
      };

      loginLimits = [
        {
          domain = "*";
          type = "hard";
          item = "maxlogins";
          value = "10";
        }

        {
          domain = "*";
          type = "hard";
          item = "core";
          value = "0";
        }
      ];
    };
  };

  ##############################################################
  # Fail2Ban
  ##############################################################

  services.fail2ban = {

    enable = true;

    maxretry = 3;

    findtime = "10m";

    bantime = "1h";

    ignoreIP = [
      "127.0.0.0/8"
      "::1"
      "100.64.0.0/10"
    ];

    bantime-increment = {
      enable = true;

      overalljails = true;

      maxtime = "168h";

      multipliers = "2 4 8 16 32 64 128 256 512 1024";
    };

    jails = {

      sshd.settings = {
        enabled = true;

        filter = "sshd";

        backend = "%(sshd_backend)s";

        port = "ssh";

        logpath = "%(sshd_log)s";

        maxretry = 3;

        findtime = "10m";

        bantime = "1h";
      };
    };
  };

  ##############################################################
  # Systemd
  ##############################################################

  systemd = {

    coredump.enable = false;

    tmpfiles.rules = [

      "d /var/log/audit 0750 root root -"

      "f /var/log/sudo.log 0600 root root -"

      "d /var/log/fail2ban 0750 root root -"
    ];
  };

  ##############################################################
  # Packages
  ##############################################################

  environment.systemPackages = with pkgs; [
    aide
    audit
    fail2ban
    lynis
    apparmor-utils
    apparmor-parser
    usbutils
    pciutils
    lsof
    strace
    tcpdump
    nmap
    nftables
  ];
}
