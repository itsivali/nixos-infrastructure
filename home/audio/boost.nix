##############################################################################
#
# Home — Audio: EasyEffects Volume Boost
#
# Purpose
# -------
# Declarative EasyEffects volume boost and limiter. Runs as a systemd
# user service after graphical login, providing controlled software
# gain (+8 dB default) with a safety limiter (-1 dBFS ceiling).
#
# Ownership
# ---------
# systemd.user.services.easyeffects, home.file (output preset)
#
# Behavior
# --------
# The gain is applied in the software domain AFTER ALSA hardware volume
# (which the boot alsa-init script sets to 100%). This produces the
# target volume curve:
#
#   0%  → muted
#  10%  → quiet
#  25%  → moderate
#  40%  → strong (+8 dB gain visible)
#  60%  → loud
#  80%  → very loud
# 100%  → maximum controlled output
#
# The limiter prevents digital clipping above -1 dBFS regardless of
# gain settings. This is safe for all audio workloads.
#
# First launch: select the "Boost" preset in EasyEffects → Output.
# After that, EasyEffects remembers the selection across logins.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  boostCfg = config.ivali.desktop.common.audio.boost or { enable = false; gainDb = 8.0; };
in
{
  config = lib.mkIf (boostCfg.enable or false) {
    home.packages = [ pkgs.easyeffects ];

    # EasyEffects output preset: +8 dB gain with limiter at -1 dBFS
    home.file.".config/easyeffects/output/boost.json" = {
      text = builtins.toJSON {
        input = [ ];
        output = [
          {
            name = "volume";
            bypass = false;
            parameters = {
              weight = 100;
              amplification = boostCfg.gainDb;
              muted = false;
            };
          }
          {
            name = "limiter";
            bypass = false;
            parameters = {
              mode = 1;
              limit = boostCfg.limiterThreshold;
              release = 50.0;
              threshold = boostCfg.limiterThreshold;
              ratio = 20.0;
              knee = 6.0;
              preamp = 0.0;
              makeup = 0.0;
              auto-release = -1;
              hysteresis = false;
              hysteresis-threshold = 0.0;
              hysteresis-ratio = 1.0;
            };
          }
        ];
      };
    };

    systemd.user.services.easyeffects = {
      Unit = {
        Description = "EasyEffects audio processing (volume boost + limiter)";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.easyeffects}/bin/easyeffects --gapplication-service";
        Restart = "on-failure";
        RestartSec = 10;
        StartLimitBurst = 5;
        StartLimitIntervalSec = 300;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
