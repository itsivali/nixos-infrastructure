#!/usr/bin/env bash
# desktop/discovery.sh — Desktop application discovery bootstrap
#
# Loaded by bot.sh. Initializes the application registry from .desktop files.
# DESKTOP_DIRS is defined in config.sh.
# app_discover_all / app_registry_load are in lib/app_registry.sh.
##############################################################################

# Pre-load the registry at startup so /open and /apps are fast.
app_registry_load
