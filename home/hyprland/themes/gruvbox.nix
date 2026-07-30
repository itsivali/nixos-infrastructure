let
  hexDigit = d: {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  }.${builtins.substring 0 1 d};

  hexByte = hex: hexDigit (builtins.substring 0 1 hex) * 16 + hexDigit (builtins.substring 1 1 hex);

  stripHash = s: builtins.substring 1 (builtins.stringLength s - 1) s;

  raw = {
    bg = "#282828";
    bg1 = "#3c3836";
    bg2 = "#504945";
    bg3 = "#665c54";
    fg = "#ebdbb2";
    fg1 = "#d5c4a1";
    fg2 = "#bdae93";
    red = "#fb4934";
    green = "#b8bb26";
    yellow = "#fabd2f";
    blue = "#83a598";
    purple = "#d3869b";
    aqua = "#8ec07c";
    orange = "#fe8019";
    gray = "#928374";
    bgHard = "#1d2021";
    bgSoft = "#32302f";
  };

  toRgba = hex: alphaHex:
    let
      r = hexByte (builtins.substring 1 2 hex);
      g = hexByte (builtins.substring 3 2 hex);
      b = hexByte (builtins.substring 5 2 hex);
      a = (hexByte alphaHex) / 255.0;
    in
    "rgba(${toString r}, ${toString g}, ${toString b}, ${toString a})";
in
{
  name = "gruvbox";
  displayName = "Gruvbox Dark";

  colors = raw // {
    accent = raw.orange;

    activeBorder = "rgba(${stripHash raw.orange}ff) rgba(${stripHash raw.yellow}ff) 45deg";
    inactiveBorder = "rgba(${stripHash raw.bg2}aa)";
    shadowColor = "rgba(${stripHash raw.bg}44)";
  };

  css = {
    bgA65 = toRgba raw.bg "a6";
    bgA85 = toRgba raw.bg "d9";
    bgA95 = toRgba raw.bg "f2";
  };

  wallpaper = {
    filename = "default.jpg";
    lockscreen = "lockscreen.jpg";
  };

  fonts = {
    sans = "Inter";
    monospace = "MesloLGS NF";
    size = 11;
  };

  gtk = {
    theme = "adw-gtk3-dark";
    iconTheme = "Tela-dark";
    cursorTheme = "Bibata-Modern-Ice";
  };
}
