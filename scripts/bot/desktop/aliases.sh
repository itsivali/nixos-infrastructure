#!/usr/bin/env bash
# desktop/aliases.sh — Friendly name → executable mappings
#
# Loaded by lib/app_registry.sh. Add custom aliases here.
# Convention: alias name is lowercase, no spaces.
##############################################################################

# ── Terminal ──────────────────────────────────────────────────────────────
app_add_alias "terminal"  "kgx"
app_add_alias "term"      "kgx"
app_add_alias "shell"     "kgx"
app_add_alias "console"   "kgx"
app_add_alias "bash"      "bash"

# ── File Manager ──────────────────────────────────────────────────────────
app_add_alias "files"     "nautilus"
app_add_alias "file"      "nautilus"
app_add_alias "nautilus"  "nautilus"

# ── Browser ───────────────────────────────────────────────────────────────
app_add_alias "browser"   "firefox"
app_add_alias "web"       "firefox"
app_add_alias "firefox"   "firefox"

# ── Editors ───────────────────────────────────────────────────────────────
app_add_alias "editor"    "zeditor"
app_add_alias "code"      "zeditor"
app_add_alias "zed"       "zeditor"
app_add_alias "vim"       "vim"

# ── System Tools ──────────────────────────────────────────────────────────
app_add_alias "settings"  "gnome-control-center"
app_add_alias "control"   "gnome-control-center"
app_add_alias "monitor"   "gnome-system-monitor"
app_add_alias "disks"     "gnome-disks"
app_add_alias "camera"    "snapshot"
app_add_alias "extensions" "extension-manager"
app_add_alias "tweaks"    "gnome-tweaks"
app_add_alias "calculator" "gnome-calculator"
app_add_alias "btop"      "btop"
app_add_alias "htop"      "htop"
app_add_alias "task"      "gnome-system-monitor"

# ── Network ───────────────────────────────────────────────────────────────
app_add_alias "localsend" "localsend_app"

# ── Office ────────────────────────────────────────────────────────────────
app_add_alias "libreoffice" "libreoffice"
app_add_alias "libre"       "libreoffice"
