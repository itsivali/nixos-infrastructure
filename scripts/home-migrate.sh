#!/usr/bin/env bash
#
# bootstrap-home-structure.sh
#
# Creates the Home Manager module hierarchy.
# Safe to run multiple times.
#

set -Eeuo pipefail

ROOT="${1:-.}"
HOME_DIR="${ROOT}/home"

##############################################################################
# Helpers
##############################################################################

create_dir() {
    mkdir -p "$1"
}

create_module() {
    local file="$1"
    local title="$2"

    if [[ -f "$file" ]]; then
        echo "✓ ${file} already exists"
        return
    fi

cat > "$file" <<EOF
##############################################################################
#
# ${title}
#
# Purpose
# -------
# TODO
#
# Owns
# ----
# TODO
#
# Rules
# -----
# • One concern only.
# • Keep this module focused.
# • If this file exceeds ~150 lines, split it.
#
##############################################################################

{ ... }:

{

}
EOF

echo "Created ${file}"
}

##############################################################################
# Directories
##############################################################################

directories=(
    editors
    environment
    git
    services
    shell
)

echo
echo "Creating Home Manager module tree..."
echo

for dir in "${directories[@]}"; do
    create_dir "${HOME_DIR}/${dir}"
done

##############################################################################
# home/default.nix
##############################################################################

DEFAULT="${HOME_DIR}/default.nix"

if [[ ! -f "$DEFAULT" ]]; then

cat > "$DEFAULT" <<'EOF'
##############################################################################
#
# Home Manager Composition Root
#
# Purpose
# -------
# Compose all Home Manager modules.
#
# This file contains imports only.
#
##############################################################################

{ ... }:

{
  imports = [
    ./ivali.nix

    ./fonts.nix

    ./shell
    ./git
    ./environment
    ./editors
    ./services
  ];
}
EOF

echo "Created home/default.nix"

fi

##############################################################################
# Module default.nix files
##############################################################################

declare -A imports

imports[editors]="./zed.nix"
imports[environment]="./packages.nix
    ./session.nix"
imports[git]="./git.nix
    ./delta.nix"
imports[services]="./auto-format.nix"
imports[shell]="
    ./aliases.nix
    ./bash.nix
    ./zsh.nix
    ./direnv.nix
    ./fzf.nix
    ./zoxide.nix
    ./atuin.nix
    ./bat.nix
    ./btop.nix
    ./eza.nix
    ./fastfetch.nix"

for module in "${directories[@]}"; do

file="${HOME_DIR}/${module}/default.nix"

if [[ -f "$file" ]]; then
    echo "✓ ${file} already exists"
    continue
fi

{
cat <<EOF
##############################################################################
#
# ${module^} Module
#
# Purpose
# -------
# Compose ${module} related configuration.
#
##############################################################################

{ ... }:

{
  imports = [
EOF

while read -r line; do
    [[ -z "$line" ]] && continue
    echo "    ${line}"
done <<< "${imports[$module]}"

cat <<EOF
  ];
}
EOF

} > "$file"

echo "Created ${file}"

done

##############################################################################
# Editors
##############################################################################

create_module \
"${HOME_DIR}/editors/zed.nix" \
"Zed Editor"

##############################################################################
# Environment
##############################################################################

create_module \
"${HOME_DIR}/environment/packages.nix" \
"Packages"

create_module \
"${HOME_DIR}/environment/session.nix" \
"Session Variables"

##############################################################################
# Git
##############################################################################

create_module \
"${HOME_DIR}/git/git.nix" \
"Git Configuration"

create_module \
"${HOME_DIR}/git/delta.nix" \
"Git Delta"

##############################################################################
# Services
##############################################################################

create_module \
"${HOME_DIR}/services/auto-format.nix" \
"Automatic Repository Formatting"

##############################################################################
# Shell
##############################################################################

for module in \
aliases \
atuin \
bash \
bat \
btop \
direnv \
eza \
fastfetch \
fzf \
zoxide \
zsh
do

create_module \
"${HOME_DIR}/shell/${module}.nix" \
"${module^}"

done

##############################################################################
# Summary
##############################################################################

cat <<'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase 1 complete.

Current Home structure

home/
├── default.nix
├── ivali.nix
├── fonts.nix
├── editors/
├── environment/
├── git/
├── services/
└── shell/

Next step

Move configuration in this order:

1. Shell
2. Git
3. Environment
4. Services
5. Editors

Goal

home/default.nix
    ↓
Composition only

home/ivali.nix
    ↓
Identity only

Everything else
    ↓
Feature modules

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
