##############################################################################
#
# Home — xfce4-terminal (Gruvbox)
#
# Purpose
# -------
# Applies the Gruvbox design system to xfce4-terminal: JetBrains Mono Nerd
# Font, orange cursor, solid Gruvbox background and the Gruvbox 16-color ANSI
# palette — the same palette the old GNOME Terminal profile shipped. The
# single source of truth for every color is theme/gruvbox/terminal.nix, which
# derives its palette from theme/gruvbox/colors.nix — nothing is hard-coded
# here.
#
# Ownership
# ---------
# home.file.".config/xfce4/terminal/terminalrc"
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  theme = import ../../theme/gruvbox;
  font = "${theme.terminal.font} ${toString theme.terminal.fontSize}";
  # xfce4-terminal's ColorPalette is 16 hex colors separated by ';'.
  palette = lib.concatStringsSep ";" theme.terminal.palette;
in
{
  # xfce4-terminal stores its configuration in
  # ~/.config/xfce4/terminal/terminalrc. Dropping the file directly is the
  # simplest reproducible way to apply the Gruvbox profile without relying
  # on a separate external colorscheme file.
  home.file.".config/xfce4/terminal/terminalrc".text = ''
    [Configuration]
    FontName=${font}
    MiscAlwaysShowTabs=FALSE
    MiscBell=FALSE
    MiscCopyOnSelect=TRUE
    MiscShowUnsafePasteDialog=TRUE
    MiscConfirmClose=TRUE
    MiscCursorBlinks=FALSE
    MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
    MiscScrollbarPosition=TERMINAL_SCROLLBAR_POSITION_RIGHT
    MiscScrollbackLines=10000
    MiscMouseAutohide=TRUE
    MiscOnboarding=TRUE
    MiscToolbarDefault=FALSE
    MiscWorkaroundVimTitle=FALSE
    MiscTabCloseButtons=TRUE

    [ColorPalette]
    Palette=${palette}
    BackgroundColor=${theme.terminal.background}
    ForegroundColor=${theme.terminal.foreground}
    CursorColor=${theme.terminal.cursor}
    SelectionBackgroundColor=${theme.terminal.selectionBackground}
  '';
}
