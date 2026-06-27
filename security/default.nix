# security/default.nix
#
# System security, authentication and host hardening.
#
# Auto-discovers sibling modules:
#   firewall.nix
#   tailscale.nix
#

{ pkgs, ... }:

{
  imports = import ../lib/auto-imports.nix ./.;

  ##############################################################
  # Security
  ##############################################################

  security = {

    ############################################################
    # sudo
    ############################################################

    sudo = {
      enable = true;

      execWheelOnly = true;

      extraConfig = ''
        Defaults timestamp_timeout=5
        Defaults passwd_tries=3
        Defaults use_pty
        Defaults logfile="/var/log/sudo.log"
      '';
    };

    ############################################################
    # Kernel Protection
    ############################################################

    protectKernelImage = true;

    lockKernelModules = true;

    ############################################################
    # Realtime
    ############################################################

    rtkit.enable = true;

    ############################################################
    # PolicyKit
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

      killUnconfinedConfinables = false;

      packages = [
        pkgs.apparmor-profiles
      ];
    };

    ############################################################
    # Audit
    ############################################################

    audit.enable = false;

    auditd.enable = false;

    ############################################################
    # PAM
    ############################################################

    pam = {

      services = {

        login.fprintAuth = false;

        sudo.fprintAuth = false;
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

    bantime = "1h";

    ignoreIP = [
      "127.0.0.0/8"
      "::1"
    ];

    bantime-increment = {
      enable = true;
      overalljails = true;
      maxtime = "168h";
      multipliers = "2 4 8 16 32 64 128 256 512 1024";
    };

    jails.sshd.settings = {
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

  ##############################################################
  # Systemd
  ##############################################################

  systemd = {

    coredump.enable = false;

    tmpfiles.rules = [

      "d /var/log/audit 0750 root root -"

      "f /var/log/sudo.log 0600 root root -"
    ];
  };

  ##############################################################
  # Security Utilities
  ##############################################################

  environment.systemPackages = with pkgs; [
    aide
    audit
    lynis
    apparmor-utils
    apparmor-parser
    nftables
    tcpdump
    lsof
    strace
    usbutils
    pciutils
  ];
}
