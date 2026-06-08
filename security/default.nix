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
    #   1. audit_log_subj_ctx spam because AppArmor labels aren't ready yet
    #   2. rules file conflict when merged with any other audit config
    # -e 1 (enabled, not immutable) lets auditd reload cleanly on rebuild.
    audit.enable = true;
    audit.rules = [
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/gshadow -p wa -k identity"
      "-w /etc/sudoers -p wa -k sudoers"
      "-w /etc/ssh/ -p wa -k ssh"
      "-w /etc/systemd/system/ -p wa -k systemd"
    ];

    auditd.enable = true;

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

  # auditd must start after AppArmor so labels exist before rules load.
  systemd.services.auditd = {
    after = [ "apparmor.service" "local-fs.target" ];
    wants = [ "apparmor.service" ];
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

