##############################################################################
#
# GRUB Theme — NixOS Snowflake
#
# Purpose
# -------
# Custom GRUB bootloader theme with the NixOS snowflake logo as background.
# Provides a clean, branded boot menu for generation selection.
#
# Ownership
# ---------
# boot.grub.theme, theme.grub.*
#
# Does NOT Own
# ------------
# - Bootloader enable/disable (boot/loader.nix)
# - Kernel parameters (boot/kernel.nix)
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  # NixOS snowflake logo (white variant for dark backgrounds)
  # from the official nixos-artwork repository.
  nixos-logo = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nixos-white.png";
    sha256 = "1ljs8ppl7qrnvfczvb0gwk29rlnjys448nj7prl0nkv6kbz3zdnr";
  };

  # GRUB theme configuration
  grubTheme = pkgs.runCommand "grub-theme-nixos" { } ''
    mkdir -p $out/share/grub/themes/nixos

    # Copy the NixOS logo as background
    cp ${nixos-logo} $out/share/grub/themes/nixos/background.png

    # Create theme configuration
    cat > $out/share/grub/themes/nixos/theme.txt << 'THEME_EOF'
    # GRUB theme for NixOS — Snowflake edition

    # Global settings
    title-text: ""
    title-color: "#ffffff"
    title-font: "DejaVu Sans Mono Bold 20"

    # Desktop wallpaper (NixOS snowflake on dark background)
    desktop-image: "background.png"
    desktop-color: "#1a1b26"

    # Terminal appearance
    terminal-font: "DejaVu Sans Mono 14"
    terminal-color: "#c0caf5"

    # Boot menu box
    + boot_menu {
      left = 30%
      top = 40%
      width = 40%
      height = 50%
      item_color = "#c0caf5"
      selected_item_color = "#7aa2f7"
      item_height = 36
      item_padding = 8
      item_spacing = 4
      selected_item_pixmap_style = "select_*.png"
    }

    # Progress bar
    + progress_bar {
      left = 35%
      top = 92%
      width = 30%
      height = 18
      bg_color = "#24283b"
      fg_color = "#7aa2f7"
      border_color = "#3b4261"
      border_width = 1
      bar_color = "#7aa2f7"
      bar_height = 12
      text_color = "#c0caf5"
      text = "@TIMEOUT@"
    }

    # Message area (for kernel/initrd loading messages)
    + label {
      top = 2%
      left = 30%
      width = 40%
      align = "center"
      text = "NixOS"
      color = "#7aa2f7"
      font = "DejaVu Sans Mono Bold 28"
    }
    THEME_EOF

    # Create a simple selection highlight image (blue rounded rectangle)
    ${pkgs.imagemagick}/bin/convert -size 400x36 xc:"#7aa2f7" \
      -alpha set -channel A -evaluate set 60% +channel \
      $out/share/grub/themes/nixos/select_wide.png 2>/dev/null || \
    ${pkgs.coreutils}/bin/touch $out/share/grub/themes/nixos/select_wide.png

    # Copy the wide select image as the standard select pattern
    cp $out/share/grub/themes/nixos/select_wide.png \
       $out/share/grub/themes/nixos/select_normal.png 2>/dev/null || true
    cp $out/share/grub/themes/nixos/select_wide.png \
       $out/share/grub/themes/nixos/select_highlight.png 2>/dev/null || true
  '';
in
{
  # Expose the theme for use by boot/loader.nix
  options.theme.grub.nixos = lib.mkEnableOption "NixOS GRUB theme with snowflake logo";

  config = lib.mkIf (config.theme.grub.nixos or false) {
    boot.grub = {
      theme = grubTheme;
    };
  };
}
