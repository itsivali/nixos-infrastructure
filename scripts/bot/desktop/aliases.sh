#!/usr/bin/env bash
# desktop/aliases.sh — Friendly name -> executable mappings
#
# Loaded by lib/app_registry.sh. Add custom aliases here.
# Convention: alias name is lowercase, no spaces.
##############################################################################

# -- Terminal --------------------
app_add_alias "terminal"  "gnome-terminal"
app_add_alias "term"      "gnome-terminal"
app_add_alias "shell"     "gnome-terminal"
app_add_alias "console"   "gnome-console"
app_add_alias "bash"      "bash"

# -- File Manager ---------------
app_add_alias "files"     "nautilus"
app_add_alias "file"      "nautilus"
app_add_alias "dolphin"   "nautilus"

# -- Browser --------------------
app_add_alias "browser"   "firefox"
app_add_alias "web"       "firefox"
app_add_alias "firefox"   "firefox"

# -- Editors --------------------
app_add_alias "editor"    "zeditor"
app_add_alias "code"      "zeditor"
app_add_alias "zed"       "zeditor"
app_add_alias "vim"       "vim"

# -- System Tools ---------------
app_add_alias "settings"  "gnome-control-center"
app_add_alias "monitor"   "btop"
app_add_alias "disks"     "gnome-disks"
app_add_alias "btop"      "btop"
app_add_alias "htop"      "htop"
app_add_alias "task"      "btop"

# -- Media ---------------------
app_add_alias "image"     "eog"
app_add_alias "photo"     "eog"
app_add_alias "picture"   "eog"
app_add_alias "video"     "totem"
app_add_alias "player"    "totem"
app_add_alias "pdf"       "evince"
app_add_alias "document"  "evince"
app_add_alias "reader"    "evince"

# -- GNOME Utilities -----------
app_add_alias "calculator"    "gnome-calculator"
app_add_alias "calc"          "gnome-calculator"
app_add_alias "fonts"         "gnome-font-viewer"
app_add_alias "maps"          "gnome-maps"
app_add_alias "weather"       "gnome-weather"
app_add_alias "screenshot"    "gnome-screenshot"
app_add_alias "contacts"      "gnome-contacts"
app_add_alias "logs"          "gnome-logs"
app_add_alias "tweaks"        "gnome-tweaks"
app_add_alias "extensions"    "gnome-extensions"
app_add_alias "disk"          "gnome-disks"
app_add_alias "disks"         "gnome-disks"

# -- Network --------------------
app_add_alias "localsend" "localsend_app"

# -- Office ---------------------
app_add_alias "libreoffice" "libreoffice"
app_add_alias "libre"       "libreoffice"
