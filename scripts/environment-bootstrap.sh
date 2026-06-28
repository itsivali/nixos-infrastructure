#!/usr/bin/env bash
#
# ivali-environment-bootstrap.sh
#
# Bootstrap the Home Manager Environment module.
# Safe to run multiple times.
#

set -Eeuo pipefail

ROOT="${1:-$(pwd)}"
ENV_DIR="${ROOT}/home/environment"

##############################################################################
# UI
##############################################################################

info()    { printf "\033[1;34m▶ %s\033[0m\n" "$1"; }
success() { printf "\033[1;32m✓ %s\033[0m\n" "$1"; }

##############################################################################
# Helpers
##############################################################################

create_file() {
    local file="$1"

    if [[ -f "$file" ]]; then
        success "$(realpath --relative-to="$ROOT" "$file") already exists"
        return
    fi

    mkdir -p "$(dirname "$file")"
    cat > "$file"
    success "Created $(realpath --relative-to="$ROOT" "$file")"
}

##############################################################################
# Begin
##############################################################################

info "Bootstrapping Environment module..."

mkdir -p "$ENV_DIR"

##############################################################################
# default.nix
##############################################################################

create_file "$ENV_DIR/default.nix" <<'EOF'
##############################################################################
#
# Environment Module
#
# Purpose
# -------
# Compose all Home Manager environment modules.
#
# Responsibilities
# ----------------
# • User packages
# • Session variables
# • Environment variables
# • XDG configuration
# • Locale configuration
#
# Rules
# -----
# • This file MUST contain imports only.
# • Never place configuration here.
#
##############################################################################

{ ... }:

{
  imports = [
    ./packages.nix
    ./session.nix
    ./variables.nix
    ./xdg.nix
    ./locale.nix
  ];
}
EOF

##############################################################################
# packages.nix
##############################################################################

create_file "$ENV_DIR/packages.nix" <<'EOF'
##############################################################################
#
# Environment Packages
#
# Purpose
# -------
# Install packages that belong to the user's environment.
#
# Owns
# ----
# • home.packages
#
# Does NOT own
# -------------
# • Git packages
# • Shell-specific packages
# • Editor packages
#
##############################################################################

{ pkgs, ... }:

{
  home.packages =
    (import ../../packages/user { inherit pkgs; })
    ++ (with pkgs; [

      ########################################################################
      # TODO
      ########################################################################

    ]);
}
EOF

##############################################################################
# session.nix
##############################################################################

create_file "$ENV_DIR/session.nix" <<'EOF'
##############################################################################
#
# Session Variables
#
# Purpose
# -------
# Configure environment variables exported for every login session.
#
# Owns
# ----
# • home.sessionVariables
#
##############################################################################

{ ... }:

{
  home.sessionVariables = {

    ##########################################################################
    # TODO
    ##########################################################################

  };
}
EOF

##############################################################################
# variables.nix
##############################################################################

create_file "$ENV_DIR/variables.nix" <<'EOF'
##############################################################################
#
# Environment Variables
#
# Purpose
# -------
# Future home for additional environment configuration.
#
# Examples
# --------
# • PATH additions
# • home.sessionPath
# • Custom exports
# • Development environment variables
#
##############################################################################

{ ... }:

{

}
EOF

##############################################################################
# xdg.nix
##############################################################################

create_file "$ENV_DIR/xdg.nix" <<'EOF'
##############################################################################
#
# XDG Configuration
#
# Purpose
# -------
# Configure XDG base directories and user configuration files.
#
# Future responsibilities
# -----------------------
# • xdg.enable
# • xdg.userDirs
# • xdg.configFile
# • MIME associations
#
##############################################################################

{ ... }:

{

}
EOF

##############################################################################
# locale.nix
##############################################################################

create_file "$ENV_DIR/locale.nix" <<'EOF'
##############################################################################
#
# Locale Configuration
#
# Purpose
# -------
# Configure language, locale and regional preferences.
#
# Future responsibilities
# -----------------------
# • LANG
# • LC_ALL
# • LC_TIME
# • Timezone
# • Keyboard locale
#
##############################################################################

{ ... }:

{

}
EOF

##############################################################################
# Summary
##############################################################################

cat <<'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Environment module bootstrapped successfully.

Created:

home/environment/
├── default.nix
├── locale.nix
├── packages.nix
├── session.nix
├── variables.nix
└── xdg.nix

Next step:

Move

• home.packages
• home.sessionVariables

from

home/ivali.nix

into

packages.nix
session.nix

Then run:

    nix fmt
    deadnix
    statix check
    nix flake check

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF


