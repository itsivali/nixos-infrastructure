#!/usr/bin/env bash
#
# Switch user: lock the current session, then ask GDM to open a fresh login
# display on a new VT. CreateTransientDisplay is the method GDM's D-Bus
# policy allows any logged-in user to call (the same path GNOME Shell uses
# for its Switch User action), so no Polkit prompt is required.
#
set -Eeuo pipefail

hyprlock 2>/dev/null &

sleep 0.5

if ! gdbus call --system \
  --dest org.gnome.DisplayManager \
  --object-path /org/gnome/DisplayManager/LocalDisplayFactory \
  --method org.gnome.DisplayManager.Local.DisplayFactory.CreateTransientDisplay \
  >/dev/null 2>&1; then
  notify-send -a waybar -u critical "Switch user" \
    "Could not open a new login display (GDM transient display unavailable)."
  exit 1
fi
