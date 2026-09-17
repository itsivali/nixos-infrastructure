##############################################################################
#
# Plymouth
#
# Purpose
# -------
# Graphical boot splash screen using a Mokka-themed two-step theme: Mokka
# background, accent-purple progress bar, reusing the upstream spinner
# animation frames (recolored by the two-step module's foreground color).
# Colors derive from theme/mokka/plymouth.nix.
#
# Ownership
# ---------
# boot.plymouth, theme.mokka.plymouth
#
# Does NOT Own
# ------------
# - Kernel parameters (boot/kernel.nix) — quiet, splash
# - Bootloader (boot/loader.nix)
# - TPM (boot/tpm.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  ply = import ../theme/mokka/plymouth.nix;

  # Mokka two-step theme. The two-step module renders a progress bar whose
  # colors come from this file; the animation frames are the upstream
  # spinner PNGs (recolored to plymouth.theme.foreground by the module).
  mokkaTheme = pkgs.runCommand "plymouth-theme-mokka" { } ''
    mkdir -p $out/share/plymouth/themes/mokka
    cd $out/share/plymouth/themes/mokka

    cp -r ${pkgs.plymouth}/share/plymouth/themes/spinner/animation-*.png .
    cp ${pkgs.plymouth}/share/plymouth/themes/spinner/bullet.png .
    cp ${pkgs.plymouth}/share/plymouth/themes/spinner/entry.png .

    cat > mokka.plymouth <<EOF
    [Plymouth Theme]
    Name=Mokka
    Description=Mokka (Catppuccin Mocha Mauve) boot splash
    ModuleName=two-step

    [two-step]
    Font=Cantarell 12
    TitleFont=Cantarell Light 30
    ImageDir=$out/share/plymouth/themes/mokka
    DialogHorizontalAlignment=.5
    DialogVerticalAlignment=.382
    TitleHorizontalAlignment=.5
    TitleVerticalAlignment=.382
    HorizontalAlignment=.5
    VerticalAlignment=.7
    WatermarkHorizontalAlignment=.5
    WatermarkVerticalAlignment=.96
    Transition=none
    TransitionDuration=0.0
    BackgroundStartColor=0x${lib.removePrefix "#" ply.background}
    BackgroundEndColor=0x${lib.removePrefix "#" ply.background}
    ProgressBarBackgroundColor=0x313244
    ProgressBarForegroundColor=0x${lib.removePrefix "#" ply.accent}
    MessageBelowAnimation=true

    [boot-up]
    UseEndAnimation=false

    [shutdown]
    UseEndAnimation=false

    [reboot]
    UseEndAnimation=false
    EOF
  '';
in
{
  boot.plymouth = {
    enable = true;
    theme = "mokka";
    themePackages = [ mokkaTheme ];
  };
}
