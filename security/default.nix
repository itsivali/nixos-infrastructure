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
      # boot because they run unconfined by default. Keep it false and load
      # the docker-default profile explicitly instead.
      killUnconfinedConfinables = false;

      packages = [ pkgs.apparmor-profiles ];
    };

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

  # Load the docker-default AppArmor profile so Docker containers are
  # confined rather than unconfined. This is the correct fix for the
  # killUnconfinedConfinables issue — confine them, don't kill them.
  systemd.services.apparmor-docker-default = lib.mkIf config.virtualisation.docker.enable {
    description = "Load docker-default AppArmor profile";
    wantedBy = [ "multi-user.target" ];
    before = [ "docker.service" ];
    after = [ "apparmor.service" ];
    requires = [ "apparmor.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.apparmor}/bin/apparmor_parser -r -W ${pkgs.apparmor-profiles}/etc/apparmor.d/docker-default";
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
