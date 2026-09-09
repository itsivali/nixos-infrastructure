##############################################################################
#
# Zsh Clipboard Functions
#
# Purpose
# -------
# Session-aware clipboard wrappers. Under a Wayland desktop the underlying
# tool is wl-clipboard (wl-copy/wl-paste); under X11/XWayland it is xclip.
# The functions dispatch on XDG_SESSION_TYPE so a single clip/cclip/cclear
# interface works on every desktop.
#
# Ownership
# ---------
# programs.zsh.initContent
#
# Responsibilities
# ----------------
# - clip  : copy stdin or argument to the clipboard
# - cclip : paste the clipboard to stdout
# - cclear: clear the clipboard
#
# Why functions (not aliases)
# ---------------------------
# A shell alias expanding to "if ...; then wl-copy; else xclip ...; fi" would
# swallow piped stdin (the `if` consumes it). Defining real BASH/zsh functions
# keeps `echo secret | clip` and `secret-tool lookup ... | clip` working.
#
##############################################################################

{ lib, ... }:

{
  programs.zsh.initContent = lib.mkAfter ''
    # Session-aware clipboard: Wayland -> wl-copy/wl-paste, X11 -> xclip.
    clip() {
      if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        wl-copy
      else
        xclip -selection clipboard
      fi
    }
    cclip() {
      if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        wl-paste
      else
        xclip -selection clipboard -o
      fi
    }
    cclear() {
      if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
        wl-copy --clear
      else
        xclip -selection clipboard -i /dev/null
      fi
    }
  '';
}
