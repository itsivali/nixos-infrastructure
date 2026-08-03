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
  windowrule = [
    # Floating rules for dialogs, calculators, clipboards, managers
    "float 1, match:class ^(Rofi)$"
    "float 1, match:class ^(pavucontrol)$"
    "float 1, match:class ^(blueman-manager)$"
    "float 1, match:class ^(nm-connection-editor)$"
    "float 1, match:class ^(org.gnome.Calculator)$"
    "float 1, match:class ^(swappy)$"
    "float 1, match:title ^(Open File)$"
    "float 1, match:title ^(Save File)$"

    # Opacity rules
    "opacity 0.95 0.90, match:class ^(kitty)$"
    "opacity 0.95 0.90, match:class ^(kitty-dropdown)$"
    "opacity 0.98 0.95, match:class ^(code)$"
    "opacity 0.98 0.95, match:class ^(zed)$"

    # Picture-in-Picture window rules
    "float 1, match:title ^(Picture-in-Picture)$"
    "pin 1, match:title ^(Picture-in-Picture)$"
    "move 72% 72%, match:title ^(Picture-in-Picture)$"
    "size 25% 25%, match:title ^(Picture-in-Picture)$"
  ];

  layerrule = [
    "blur 1, match:namespace waybar"
    "blur 1, match:namespace swaync-control-center"
    "blur 1, match:namespace swaync-notification-window"
    "blur 1, match:namespace rofi"
    "blur 1, match:namespace wlogout"
  ];
}
