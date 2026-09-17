##############################################################################
#
# Theme — Mokka (GTK Configuration)
#
# Purpose
# -------
# GTK theme settings for Catppuccin Mocha Mauve under KDE Plasma.
# GTK applications (Firefox, Electron, etc.) use these settings.
# Derived from upstream Garuda Mokka gtk-3.0/settings.ini and gtk-4.0/settings.ini.
#
# Ownership
# ---------
# theme.mokka.gtk
#
##############################################################################

{
  # Catppuccin GTK theme (from nixpkgs: catppuccin-gtk variant=mocha accents=["mauve"])
  theme = "Catppuccin-Mocha-Standard-Mauve-Dark";

  # Icon theme (from nixpkgs: tela-icon-theme, includes dracula-dark variant)
  iconTheme = "Tela-circle-dracula-dark";

  # Cursor theme (from nixpkgs: catppuccin-cursors palette=mocha color=Mauve)
  cursorTheme = "Catppuccin-Mocha-Mauve-Cursors";
  cursorSize = 24;

  # Font
  font = {
    name = "Inter";
    size = 10;
    weight = "Bold";
  };
}
