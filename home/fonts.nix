##############################################################################
#
# Home Fonts
#
# Purpose
# -------
# Installs development, Microsoft Office compatibility, and general system
# fonts into the user Home Manager profile with fontconfig enabled.
#
# Ownership
# ---------
# Willis Ivali <ivali>
#
# Responsibilities
# ----------------
# - Install Nerd Fonts (Meslo LG, Fira Code, JetBrains Mono) for terminals
# - Install Microsoft Office compatibility fonts (corefonts, vista-fonts, Liberation)
# - Install general typography (Noto, Font Awesome, emoji)
# - Enable fontconfig for font registration and caching
#
##############################################################################

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
