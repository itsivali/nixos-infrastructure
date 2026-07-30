let
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

  stripHash = s: builtins.substring 1 (builtins.stringLength s - 1) s;
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
