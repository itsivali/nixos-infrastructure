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
      # killUnconfinedConfinables = true would terminate Docker containers at
      # boot because they run unconfined by default. Keep false.
      killUnconfinedConfinables = false;
      packages = [ pkgs.apparmor-profiles ];
    };

    # Minimal audit rules — the execve catch-all was removed because it
    # generates thousands of audit_log_subj_ctx errors at boot when
    # AppArmor labels haven't been assigned to early processes yet.
    # File-watch rules are safe and don't trigger the spam.
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

  # Ensure auditd starts after AppArmor so labels are present before
  # rules load — this eliminates the audit_log_subj_ctx spam.
  systemd.services.auditd = {
    after = [ "apparmor.service" "local-fs.target" ];
    wants = [ "apparmor.service" ];
  };

  # Load the docker-default AppArmor profile only when Docker is enabled.
  # Without the mkIf guard this service fails on machines without Docker.
  systemd.services.apparmor-docker-default = lib.mkIf config.virtualisation.docker.enable {
    description = "Load docker-default AppArmor profile";
    wantedBy = [ "multi-user.target" ];
    before = [ "docker.service" ];
    after = [ "apparmor.service" ];
    requires = [ "apparmor.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.apparmor-parser}/bin/apparmor_parser -r -W ${pkgs.apparmor-profiles}/etc/apparmor.d/docker-default";
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
