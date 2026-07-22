##############################################################################
#
# Falco
#
# Purpose
# -------
# Runtime security detection with Falco.
# Supports workstation and server profiles with different rule sets.
#
# Ownership
# ---------
# systemd.services.falco
#
# Responsibilities
# ----------------
# - Runtime threat detection
# - Syscall monitoring
# - File integrity monitoring
# - Network connection tracking
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.observability;

  # Workstation rules: focus on user activity, desktop apps, browsers
  workstationRules = pkgs.writeText "falco-workstation-rules.yaml" - ''
    - rule: Terminal shell in container
      desc: A shell was used as the entrypoint/exec cmd into a container
      condition: >
        spawned_process and container
        and proc.name in (bash, sh, zsh, fish, dash, ksh, csh)
        and not proc.pname in (dockerd, podman, containerd-shim)
      output: >
        Shell launched in container (user=%user.name container_id=%container.id
        container_name=%container.name shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline)
      priority: WARNING
      tags: [container, shell, mit_execution]

    - rule: Launch web server in container
      desc: Detect a web server started in a container
      condition: >
        spawned_process and container
        and proc.name in (nginx, apache2, httpd, lighttpd, caddy)
      output: >
        Web server started in container (user=%user.name container_id=%container.id
        container_name=%container.name server=%proc.name parent=%proc.pname)
      priority: NOTICE
      tags: [container, web, mit_execution]

    - rule: Schedule jobs with cron
      desc: Detect cron jobs scheduled
      condition: >
        spawned_process and proc.name in (cron, crond, at, crontab)
      output: >
        Cron job scheduled (user=%user.name command=%proc.cmdline parent=%proc.pname)
      priority: INFO
      tags: [cron, mit_execution]

    - rule: Unexpected process in /tmp
      desc: Detect processes running from /tmp
      condition: >
        spawned_process and proc.exe startswith /tmp
      output: >
        Unexpected process in /tmp (user=%user.name command=%proc.cmdline
        exe=%proc.exe parent=%proc.pname)
      priority: WARNING
      tags: [filesystem, mit_defense_evasion]
  '';

  # Server rules: focus on services, SSH, network, privilege escalation
  serverRules = pkgs.writeText "falco-server-rules.yaml" - ''
    - rule: Detect SSH brute force
      desc: Detect multiple failed SSH login attempts
      condition: >
        spawned_process and proc.name = sshd
        and proc.pname != sshd
      output: >
        SSH connection attempt (user=%user.name command=%proc.cmdline
        parent=%proc.pname)
      priority: NOTICE
      tags: [ssh, mit_credential_access]

    - rule: Unexpected outbound connection
      desc: Detect unexpected outbound network connections
      condition: >
        outbound and not container
        and not proc.name in (tailscaled, systemd-resolved, ntpd, chronyd)
      output: >
        Unexpected outbound connection (user=%user.name command=%proc.cmdline
        connection=%fd.name)
      priority: WARNING
      tags: [network, mit_command_and_control]

    - rule: System service started
      desc: Detect systemd service being started
      condition: >
        spawned_process and proc.pname = systemd
      output: >
        System service started (user=%user.name command=%proc.cmdline
        parent=%proc.pname)
      priority: INFO
      tags: [systemd, mit_execution]

    - rule: Failed service restart
      desc: Detect a service that failed to start
      condition: >
        spawned_process and proc.pname = systemd
        and proc.name in (start, restart)
      output: >
        Service restart attempted (user=%user.name command=%proc.cmdline
        parent=%proc.pname)
      priority: NOTICE
      tags: [systemd, mit_impact]
  '';

in
{
  config = lib.mkIf cfg.falco.enable {
    # Select rules based on profile
    environment.etc."falco/falco_rules.yaml".source =
      if cfg.falco.profile == "workstation" then
        workstationRules
      else if cfg.falco.profile == "server" then
        serverRules
      else if cfg.falco.profile == "custom" && cfg.falco.customRulesFile != null then
        cfg.falco.customRulesFile
      else
        workstationRules;

    # Falco configuration
    environment.etc."falco/falco.yaml".text = ''
      # Falco configuration
      rules_file:
        - /etc/falco/falco_rules.yaml
        - /etc/falco/falco_rules.local.yaml

      # Output format
      json_output: ${lib.boolToString cfg.falco.enableJsonOutput}
      json_include_output_property: true
      json_include_tags_property: true

      # Logging
      log_level: info
      log_stderr: true
      log_syslog: true

      # Alerting
      priority: NOTICE
      buffered_outputs: false
      stdout_output:
        enabled: true

      # Syscall event logging
      syscall_event_drops:
        threshold: 0.1
        actions:
          - log
          - alert
        rate: 0.03333
        max_burst: 1

      # Performance
      syscall_event_compressor:
        enabled: false

      # Rules engine
      rules_engine:
        rate: 1
        burst: 1
    '';

    systemd.services.falco = {
      description = "Falco runtime security detection";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.falco}/bin/falco --modern-bpf";
        Restart = "always";
        RestartSec = "10s";

        # Memory limits (1GB observability budget)
        MemoryMax = "128M";
        MemoryHigh = "100M";
        CPUQuota = "15%";

        # Hardening
        NoNewPrivileges = false; # Falco needs privileges for BPF
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/nix/store" "/proc" "/sys" ];
        CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_NET_ADMIN CAP_SYS_PTRACE";
        AmbientCapabilities = "CAP_SYS_ADMIN CAP_NET_ADMIN CAP_SYS_PTRACE";
      };
    };
  };
}
