##############################################################################
#
# Hyprland Window & Layer Rules
#
# Purpose
# -------
# Window rules, float rules, opacity, and layer blur rules matching Hyde.
#
##############################################################################

{
  windowrulev2 = [
    # Floating rules for dialogs, calculators, clipboards, managers
    "float, class:^(Rofi)$"
    "float, class:^(pavucontrol)$"
    "float, class:^(blueman-manager)$"
    "float, class:^(nm-connection-editor)$"
    "float, class:^(org.gnome.Calculator)$"
    "float, class:^(swappy)$"
    "float, title:^(Open File)$"
    "float, title:^(Save File)$"

    # Opacity rules
    "opacity 0.95 0.90, class:^(kitty)$"
    "opacity 0.95 0.90, class:^(foot)$"
    "opacity 0.98 0.95, class:^(code)$"
    "opacity 0.98 0.95, class:^(zed)$"

    # Picture-in-Picture window rules
    "float, title:^(Picture-in-Picture)$"
    "pin, title:^(Picture-in-Picture)$"
    "move 72% 72%, title:^(Picture-in-Picture)$"
    "size 25% 25%, title:^(Picture-in-Picture)$"
  ];

  layerrule = [
    "blur, waybar"
    "blur, swaync-control-center"
    "blur, swaync-notification-window"
    "blur, rofi"
    "blur, wlogout"
    "ignorezero, waybar"
    "ignorezero, swaync-control-center"
    "ignorezero, rofi"
  ];
}
