##############################################################################
#
# Package — GNOME Shell Gruvbox Theme
#
# Purpose
# -------
# A Gruvbox-Dark recolor of the stock GNOME 50 (Tokyo) GNOME Shell theme,
# loadable through the user-themes extension (name "gruvbox-shell"). Rather
# than maintaining thousands of lines of shell CSS by hand, it recompiles
# gnome-shell's own Sass palette with the Gruvbox base colors and keeps the
# theme's st-* function calls (st-mix, -st-accent-color, ...) intact — those
# are resolved at runtime by GNOME Shell's St theme engine.
#
# The accent color is NOT hard-coded: -st-accent-color follows the active
# GNOME accent color (set to Gruvbox orange via
# org.gnome.desktop.interface.accent-color in home/theming.nix), so the
# accent matches the rest of the desktop.
#
# Usage
# -----
# Install via environment.systemPackages (from desktop/gnome/session.nix),
# enable the user-themes extension, and set
# org.gnome.shell.extensions.user-theme.name = "gruvbox-shell" (done in
# home/gnome/extensions.nix). The extension looks for the theme in the XDG
# data dirs, which include /run/current-system/sw/share/themes.
#
# Palette mapping (theme/gruvbox/colors.nix)
# -----------------------------------------
#   Adwaita token                Gruvbox      Gruvbox name
#   $_base_color_dark  #222226   #282828      bg
#   $bg_color (dark)   #36363a   #3c3836      bg1
#   $fg_color (dark)   #ffffff   #ebdbb2      fg
#   $panel_bg_color    #000000   #282828      bg (instead of black)
#
##############################################################################

{ stdenv, sassc, gnome-shell }:

stdenv.mkDerivation {
  pname = "gnome-shell-gruvbox-theme";
  version = gnome-shell.version;

  src = gnome-shell.src;

  nativeBuildInputs = [ sassc ];

  postPatch = ''
    # ── Gruvbox base palette ─────────────────────────────────────────────
    sed -i 's|$_base_color_dark: #222226;|$_base_color_dark: #282828;|' data/theme/gnome-shell-sass/_default-colors.scss
    sed -i "s|\$bg_color: if(\$variant == 'light', \$_base_color_light, #36363a);|\$bg_color: if(\$variant == 'light', \$_base_color_light, #3c3836);|" data/theme/gnome-shell-sass/_colors.scss
    sed -i "s|\$fg_color: if(\$variant == 'light', \$_base_color_dark, \$light_1);|\$fg_color: if(\$variant == 'light', \$_base_color_dark, #ebdbb2);|" data/theme/gnome-shell-sass/_colors.scss
    sed -i "s|\$panel_bg_color: if(\$variant == 'light', \$_base_color_light, \$dark_5);|\$panel_bg_color: if(\$variant == 'light', \$_base_color_light, \$_base_color_dark);|" data/theme/gnome-shell-sass/_colors.scss
  '';

  buildPhase = ''
    runHook preBuild
    # Same invocation gnome-shell's own build uses (data/theme/meson.build).
    # Derived surfaces (lighten/darken/mix of the base colors) and the
    # st-* calls are resolved statically at compile time / at runtime by St.
    sassc -a data/theme/gnome-shell-dark.scss "$TMPDIR/gruvbox-shell.css"
    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall
        mkdir -p $out/share/themes/gruvbox-shell/gnome-shell
        cp "$TMPDIR/gruvbox-shell.css" $out/share/themes/gruvbox-shell/gnome-shell/gnome-shell.css
        # Optional metadata (the user-themes extension primarily keys on the
        # gsettings "name"; kept for tooling that lists themes).
        cat > $out/share/themes/gruvbox-shell/gnome-shell/metadata.json <<'EOF'
    { "name": "gruvbox-shell" }
    EOF
        runHook postInstall
  '';
}
