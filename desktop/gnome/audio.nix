##############################################################################
#
# Desktop GNOME Audio
#
# Purpose
# -------
# Enables PipeWire audio stack with PulseAudio, WirePlumber, and JACK
# support for the GNOME desktop.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Enable PipeWire with audio, PulseAudio, WirePlumber, and JACK backends
#
##############################################################################

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.ivali.desktop.gnome.enable {
    services.pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
      jack.enable = true;
    };
  };
}
