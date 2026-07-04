# desktop/discovery.sh — .desktop file parser and application discovery
#
# Delegates to lib/app_registry.sh which contains the canonical
# _parse_desktop_file implementation.
# This file is kept as a thin compatibility layer.
##############################################################################

# Discovery is handled by lib/app_registry.sh app_discover_all.
# The _parse_desktop_file function lives in app_registry.sh (the canonical
# implementation). This file will be removed in a future cleanup.
