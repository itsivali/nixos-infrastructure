##############################################################################
#
# Desktop GNOME Audio
#
# Purpose
# -------
# PipeWire audio stack with low-latency configuration, WirePlumber session
# policy, Bluetooth codec support, and PulseAudio compatibility for GNOME.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - PipeWire with low-latency quantum (256 samples @ 48kHz = 5.3ms)
# - WirePlumber session manager with Bluetooth codec preferences
# - PulseAudio compatibility layer (PipeWire-Pulse)
# - JACK support for professional audio
#
# Why quantum=256
# ---------------
# The default quantum (1024) at 48kHz produces 21ms frames. WebRTC's AEC3
# echo canceller and jitter buffer expect ~5ms frames. The mismatch causes
# browsers (Firefox, Chrome) to resample or drop audio frames, resulting in
# choppy, robotic, stuttering audio on Google Meet, Discord, Slack, etc.
# Zoom works because it manages its own audio pipeline via PulseAudio
# directly and handles buffer negotiation internally.
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.desktop.gnome;
in
{
  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
      jack.enable = true;

      # ── Low-latency PipeWire config ────────────────────────────────────
      # 256 samples @ 48kHz = 5.3ms per buffer.
      # min-quantum prevents PipeWire from going below 256 even under load.
      # max-quantum allows scaling up to 1024 for non-realtime workloads.
      extraConfig.pipewire."92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 256;
          "default.clock.min-quantum" = 256;
          "default.clock.max-quantum" = 1024;
        };
      };

      # ── PulseAudio compat: same low-latency for Pulse clients ──────────
      # Browsers connect via PipeWire-Pulse, so this must match.
      extraConfig.pipewire-pulse."92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 256;
          "default.clock.min-quantum" = 256;
        };
      };
    };

    # ── WirePlumber: Bluetooth codec preferences ──────────────────────────
    # Enable high-quality Bluetooth codecs (AAC, LDAC, SBC-XQ, mSBC for HFP).
    services.pipewire.wireplumber.extraConfig."10-defaults" = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.codecs" = [ "aac" "ldac" "sbc" ];
      };
    };
  };
}
