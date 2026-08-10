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
#
# Why adaptive quantum
# --------------------
# WebRTC's AEC3 echo canceller and jitter buffer expect ~5ms frames, which a
# 256-sample quantum at 48kHz provides. Forcing min-quantum = 256 disables
# PipeWire's dynamic scheduling and causes stutter under load; letting the
# clock adapt (64..1024) keeps low latency for realtime apps while remaining
# stable for heavy workloads. Zoom manages its own pipeline via PulseAudio.
#
##############################################################################

{ config, lib, pkgs, ... }:

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
  };
}
