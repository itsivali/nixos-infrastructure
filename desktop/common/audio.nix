##############################################################################
#
# Desktop — Common Audio
#
# Purpose
# -------
# PipeWire audio stack with adaptive low-latency configuration, WirePlumber
# session policy, and Bluetooth codec support. Lives in the shared layer so
# every desktop host gets audio regardless of environment.
#
# Ownership
# ---------
# services.pipewire, security.rtkit
#
# Responsibilities
# ----------------
# - PipeWire with adaptive quantum (default 256 @ 48kHz = 5.3ms)
# - WirePlumber session manager with Bluetooth codec preferences
# - PulseAudio compatibility layer (PipeWire-Pulse)
# - JACK support for professional audio
# - rtkit realtime scheduling for PipeWire threads (low-latency, glitch-free
#   audio — same realtime setup Garuda ships)
# - ALSA mixer initialization for Realtek ALC236 (consistent volume across
#   browsers, video players, and system audio)
#
# Why adaptive quantum
# --------------------
# WebRTC's AEC3 echo canceller and jitter buffer expect ~5ms frames, which a
# 256-sample quantum at 48kHz provides. Forcing min-quantum = 256 disables
# PipeWire's dynamic scheduling and causes stutter under load; letting the
# clock adapt (64..1024) keeps low latency for realtime apps while remaining
# stable for heavy workloads. Zoom manages its own pipeline via PulseAudio.
#
# Why ALSA mixer init
# -------------------
# On Lenovo AMD laptops with Realtek ALC236, the ALSA hardware volume
# (Master, Speaker, Headphone) defaults to low levels. Different applications
# (browsers vs video players) request different PulseAudio volumes, and the
# low hardware ceiling means some content sounds quiet while others are
# normal. Setting ALSA levels to 100% at boot ensures PipeWire has the full
# dynamic range to work with, and the user's volume slider controls the
# final output consistently.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  audioDiagnosticScript = ../../scripts/audio-diagnostic.sh;

  # ALSA mixer initialization script: sets all playback volumes to 100%
  # so PipeWire has full dynamic range. This runs once at boot before
  # PipeWire starts, ensuring the hardware mixer is configured.
  alsa-init = pkgs.writeShellScript "alsa-init" ''
    # Wait for any ALSA card to appear (not card1 specifically)
    for i in $(seq 1 10); do
      if ls /proc/asound/card[0-9]* >/dev/null 2>&1; then break; fi
      sleep 0.5
    done

    # Set all playback volumes to 100% on all cards
    for card in /proc/asound/card[0-9]*; do
      card_num=$(basename "$card" | sed 's/card//')
      # Use amixer if available, otherwise use pactl/pw-cli
      ${pkgs.alsa-utils}/bin/amixer -c "$card_num" sset Master 100% 2>/dev/null || true
      ${pkgs.alsa-utils}/bin/amixer -c "$card_num" sset Speaker 100% 2>/dev/null || true
      ${pkgs.alsa-utils}/bin/amixer -c "$card_num" sset Headphone 100% 2>/dev/null || true
      ${pkgs.alsa-utils}/bin/amixer -c "$card_num" sset PCM 100% 2>/dev/null || true
      ${pkgs.alsa-utils}/bin/amixer -c "$card_num" sset Front 100% 2>/dev/null || true
    done
  '';
in
{
  config = lib.mkIf (config.ivali.desktop.gnome.enable or false) {
    # Realtime privileges for PipeWire: the rtkit daemon grants RT policy +
    # memlock so audio threads run without scheduling jitter. Without this,
    # calls under load crackle/drop frames (Garuda ships the same setup).
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
      jack.enable = true;

      # ── Adaptive low-latency PipeWire config ──────────────────────────
      # 256 samples @ 48kHz = 5.3ms per buffer by default; the clock may
      # shrink to 64 samples for realtime work or grow to 1024 under load.
      extraConfig.pipewire."92-adaptive-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 256;
          "default.clock.min-quantum" = 64;
          "default.clock.max-quantum" = 1024;
        };
      };

      # ── PulseAudio compat: same policy for Pulse clients ──────────────
      # Browsers connect via PipeWire-Pulse, so this must match.
      extraConfig.pipewire-pulse."92-adaptive-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 256;
          "default.clock.min-quantum" = 64;
        };
      };
    };

    # ── WirePlumber: Bluetooth codec preferences ──────────────────────────
    # High-quality Bluetooth codecs (AAC, LDAC, SBC-XQ, mSBC for HFP).
    services.pipewire.wireplumber.extraConfig."10-defaults" = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.codecs" = [ "aac" "ldac" "sbc" ];
      };
    };

    # ── WirePlumber: ALSA mixer policy for ALC236 ────────────────────────
    # Ensure ALSA mixer levels are set to maximum at PipeWire startup.
    # The ALC236 codec defaults to low volume, causing inconsistent
    # perceived loudness between browsers (which use PulseAudio volume)
    # and video players (which may use ALSA directly).
    services.pipewire.wireplumber.extraConfig."10-alsa-mixer" = {
      "monitor.alsa.rules" = [{
        "match" = {
          "alsa.card_name" = "HD-Audio Generic";
        };
        "update-props" = {
          "api.alsa.mixers.Master" = 100;
          "api.alsa.mixers.Speaker" = 100;
          "api.alsa.mixers.Headphone" = 100;
        };
      }];
    };

    # ── ALSA utils (amixer, alsactl) + audio diagnostic tool ─────────────
    # amixer/alsactl for mixer management, and an operator-installable
    # diagnostic for PipeWire/WirePlumber/Firefox audio (audio-diagnostic).
    environment.systemPackages = [
      pkgs.alsa-utils
      (pkgs.writeShellScriptBin "audio-diagnostic" ''
        exec ${audioDiagnosticScript} "$@"
      '')
    ];

    # ── Boot-time ALSA mixer initialization ──────────────────────────────
    # Runs before PipeWire to set hardware mixer levels to 100%.
    # This ensures the full dynamic range is available regardless of
    # which application is producing audio.
    systemd.services.alsa-init = {
      description = "Initialize ALSA mixer levels";
      wantedBy = [ "multi-user.target" ];
      before = [ "pipewire.service" "pipewire-pulse.service" ];
      after = [ "sound.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = alsa-init;
      };
    };
  };
}
