##############################################################################
#
# Valkey Service
#
# Purpose
# -------
# In-memory cache and message broker.
# Valkey is the Linux Foundation's open-source fork of Redis.
#
# Ownership
# ---------
# systemd.services.valkey, users.users.valkey, users.groups.valkey
#
# Responsibilities
# ----------------
# - Caching for local applications
# - Session storage
# - Rate limiting
# - Pub/Sub messaging
#
# Usage
# -----
# ivali.services.valkey.enable = true;
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.services.valkey;

  valkeyConf = pkgs.writeText "valkey.conf" ''
    # Network
    bind ${cfg.bind}
    port ${toString cfg.port}
    tcp-backlog 511
    timeout 0
    tcp-keepalive 300

    # Memory
    maxmemory ${cfg.maxMemory}
    maxmemory-policy ${cfg.maxMemoryPolicy}

    # Persistence
    ${if cfg.persistence then ''
      save 900 1
      save 300 10
      save 60 10000
      rdbcompression yes
      rdbchecksum yes
      dbfilename dump.rdb
      dir /var/lib/valkey
    '' else ''
      save ""
    ''}

    # Logging
    loglevel ${cfg.logLevel}
    logfile ""

    # Slow log
    slowlog-log-slower-than 10000
    slowlog-max-len 128

    # Max clients
    maxclients 10000

    # Disable protected mode for local use
    protected-mode no
  '';

in
{
  config = lib.mkIf cfg.enable {
    # Valkey package
    environment.systemPackages = [ pkgs.valkey ];

    # Systemd service
    systemd.services.valkey = {
      description = "Valkey In-Memory Data Store";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "notify";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/valkey";
        ExecStart = "${pkgs.valkey}/bin/valkey-server ${valkeyConf}";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";

        # User and permissions
        User = "valkey";
        Group = "valkey";
        StateDirectory = "valkey";
        StateDirectoryMode = "0700";

        # Hardening
        NoNewPrivileges = true;
        PrivateDevices = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        MemoryDenyWriteExecute = true;
        LockPersonality = true;

        # Restart
        Restart = "always";
        RestartSec = 5;
      };
    };

    # Valkey user
    users.users.valkey = {
      isSystemUser = true;
      group = "valkey";
      home = "/var/lib/valkey";
      createHome = false;
    };

    users.groups.valkey = {};

    # Redis compatibility aliases
    environment.etc."valkey/redis.conf".source = valkeyConf;
  };
}
