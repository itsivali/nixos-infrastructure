##############################################################################
#
# IVALI Control Plane Aliases
#
# Purpose
# -------
# Shortcuts for the IVALI NixOS infrastructure control plane CLI.
#
# Ownership
# ---------
# ivali control plane
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    iv = "ivali";
    ivs = "ivali status";
    ivd = "ivali doctor";
    ivv = "ivali verify";
    ivg = "ivali graph";
    ivx = "ivali explain";
    ivb = "ivali bootstrap";
    ivup = "ivali update";
    ivreb = "ivali rebuild";
    ivdep = "ivali deploy";
    ivrec = "ivali reconcile";
    ivdoc = "ivali docs";
    ivscan = "ivali scan";
  };
}
