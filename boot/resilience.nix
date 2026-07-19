##############################################################################
#
# Boot Resilience — impermanence + auto-rollback watchdog
#
# Purpose
# -------
# * impermanence: tmpfs root; only what is listed under
#   environment.persistence."/persist" survives a reboot. Keeps the
#   system clean and makes a "known-good" state reproducible.
# * autoRollback: if a generation boots but never reaches a healthy
#   target, roll back to the previous generation on the next boot
#   and notify. Closes the "bad generation locked me out" gap.
#
# Ownership
# ---------
# fleet.boot.*, systemd boot-health-mark / boot-watchdog
#
# WARNING
# -------
# impermanence is DESTRUCTIVE until you review the persistence
# list below — anything not persisted is wiped every reboot. Keep this
# disabled until you have validated the list on a spare boot.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.fleet.boot;
  persist = "/persist";
  stateDir = "${persist}/var/lib/boot-health";

  rollbackScript = pkgs.writeShellScript "boot-auto-rollback" ''
    #!/bin/sh
    set -eu

    GEN="$(readlink -f /run/current-system | sed 's#.*/\([0-9]*\)-link#\1#')"
    GRACE="$1"
    STATE="${stateDir}"

    mkdir -p "$STATE"

    # Late service writes booted-ok-<gen> once the system is healthy.
    if [ -e "$STATE/booted-ok-$GEN" ]; then
      # Healthy boot: clear the in-progress sentinel and we are done.
      rm -f "$STATE/boot-started-$GEN"
      exit 0
    fi

    if [ ! -e "$STATE/boot-started-$GEN" ]; then
      # First sight of this generation: record that a boot started.
      date +%s > "$STATE/boot-started-$GEN"
      exit 0
    fi

    # boot-started-<gen> exists but booted-ok-<gen> does not: the
    # previous attempt of THIS generation never became healthy.
    started="$(cat "$STATE/boot-started-$GEN")"
    now="$(date +%s)"
    if [ "$(( now - started ))" -lt "$GRACE" ]; then
      # Not enough time has passed to be sure; wait for next boot.
      exit 0
    fi

    echo "Generation $GEN failed to reach a healthy target; rolling back."
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild rollback
    ${pkgs.systemd}/bin/systemctl reboot
  '';
in
{
  options.fleet.boot = {
    impermanence = lib.mkEnableOption "tmpfs root with /persist persistence";

    autoRollback = lib.mkEnableOption "roll back a generation that fails to boot healthy";

    graceSec = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Seconds a generation may stay unhealthy before rollback.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.impermanence {
      # Root on tmpfs — wiped on every boot.
      # Root on tmpfs + bind-mounted persistence from the real
      # ${persist} volume. Prerequisites (manual, destructive):
      #   * a real partition mounted at ${persist}
      #   * the directories below created under ${persist}
      #   * the fileSystems."/" definition REMOVED from
      #     hardware-configuration.nix (this module overrides it)
      # Everything not listed here is wiped each boot.
      fileSystems = lib.mkMerge [
        {
          "/" = {
            device = "none";
            fsType = "tmpfs";
            options = [ "defaults" "size=2G" "mode=755" ];
            neededForBoot = true;
          };
        }
        (map
          (p: {
            "${p}" = {
              device = "${persist}${p}";
              options = [ "bind" ];
              neededForBoot = true;
            };
          })
          [
            "/etc"
            "/var/log"
            "/var/cache"
            "/var/lib/systemd"
            "/var/lib/NetworkManager"
            "/var/lib/nixos"
            "/var/lib/bluetooth"
            "/var/lib/iwd"
            "/var/lib/accounts"
            "/var/lib/alsa"
            "/var/lib/colord"
            "/var/lib/dhcpcd"
            "/var/lib/boltd"
            "/var/lib/upower"
            "/var/lib/flatpak"
            "/var/lib/portables"
            "/var/lib/snapd"
            "/var/lib/logrotate"
            "/var/lib/usermetrics"
            "/root"
            "/home/ivali"
          ])
        {
          "/etc/machine-id" = {
            device = "${persist}/etc/machine-id";
            options = [ "bind" ];
            neededForBoot = true;
          };
        }
      ];

      # sops-nix regenerates /run/secrets at boot; nothing to persist.
      # Age key lives in /home/ivali/.config/sops (persisted above).
    })

    (lib.mkIf cfg.autoRollback {
      systemd.services.boot-health-mark = {
        description = "Mark current generation as booted healthy";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          GEN="$(readlink -f /run/current-system | sed 's#.*/\([0-9]*\)-link#\1#')"
          mkdir -p "${stateDir}"
          date +%s > "${stateDir}/booted-ok-$GEN"
          rm -f "${stateDir}/boot-started-$GEN"
        '';
      };

      systemd.services.boot-watchdog = {
        description = "Roll back a generation that failed to boot healthy";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          # Give the health-mark service time to run before we decide.
          ExecStart = "${rollbackScript} ${builtins.toString cfg.graceSec}";
        };
      };
    })
  ];
}
