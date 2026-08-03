#!/usr/bin/env bash
#
# Switch user: lock the current session, then present a fresh login.
#
# On GDM hosts this uses CreateTransientDisplay (the same D-Bus path GNOME
# Shell's Switch User action uses). The Ly display manager has no equivalent
# API, so there we lock the session and point the user to the wlogout logout
# flow, which returns to the Ly login screen.
#
set -Eeuo pipefail

hyprlock 2>/dev/null &

sleep 0.5

if gdbus call --system \
  --dest org.gnome.DisplayManager \
  --object-path /org/gnome/DisplayManager/LocalDisplayFactory \
  --method org.gnome.DisplayManager.Local.DisplayFactory.CreateTransientDisplay \
  >/dev/null 2>&1; then
  exit 0
fi

notify-send -a waybar -u normal "Switch user" \
  "Ly has no second login display. Use the logout action to reach the login screen."
exit 1
