# home/fonts.nix
#
# Font configuration for development terminal (P10k), 
# Microsoft Office compatibility (LibreOffice), and system-wide use.

{ config, lib, pkgs, ... }:

{
  # Install the fonts into the user profile
  home.packages = with pkgs; [
    # ─────────────────────────────────────────────────────────────────────────
    # Terminal & Icon Fonts (Powerlevel10k & Icon Support)
    # ─────────────────────────────────────────────────────────────────────────
    # In recent nixpkgs versions, nerd-fonts is structured as a collection.
    # We install the most popular dev fonts alongside the complete symbols pack.
    nerd-fonts.meslo-lg # Default recommended font for Powerlevel10k
    nerd-fonts.fira-code # Excellent development font with ligatures
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only # Pure icon font fallback for terminal symbols

    # ─────────────────────────────────────────────────────────────────────────
    # Microsoft Office Compatibility Fonts (LibreOffice & System)
    # ─────────────────────────────────────────────────────────────────────────
    coreutils # Standard fallback tools
    corefonts # <--- Changed from msttcorefonts to corefonts
    vista-fonts # Calibri, Cambria, Consolas, Candara, etc. 

    # Open-source metrically compatible alternatives to modern MS Fonts
    # (Crucial for flawless LibreOffice formatting when MS fonts aren't enough)
    liberation_ttf # Alternates for Arial, Times New Roman, and Courier New
    carlito # Metric-compatible alternate for Calibri
    caladea # Metric-compatible alternate for Cambria

    # ─────────────────────────────────────────────────────────────────────────
    # General System Typography
    # ─────────────────────────────────────────────────────────────────────────
    noto-fonts-color-emoji
    noto-fonts
    noto-fonts-cjk-sans
    font-awesome # Additional global icon coverage
  ];

  # Enable Fontconfig so the system registers and caches these fonts correctly
  fonts.fontconfig.enable = true;
}
