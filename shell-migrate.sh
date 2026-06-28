
#!/usr/bin/env bash
#
# create-home-shell-modules.sh
#
# Creates the Home Manager shell module structure.
#
# Safe to run multiple times.
# Existing files are never overwritten.
#

set -Eeuo pipefail

ROOT="${1:-.}"
HOME_DIR="${ROOT}/home"
SHELL_DIR="${HOME_DIR}/shell"

mkdir -p "${SHELL_DIR}"

##############################################################################
# default.nix
##############################################################################

if [[ ! -f "${SHELL_DIR}/default.nix" ]]; then
cat > "${SHELL_DIR}/default.nix" <<'EOF'
##############################################################################
#
# Shell Module
#
# Purpose
# -------
# Compose all shell-related Home Manager modules.
#
# Rules
# -----
# • default.nix ONLY imports modules.
# • No configuration belongs here.
# • One concern per module.
#
##############################################################################

{ ... }:

{
  imports = [
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
    ./fastfetch.nix
  ];
}
EOF
fi

##############################################################################
# Metadata
##############################################################################

modules=(
aliases
atuin
bash
bat
btop
direnv
eza
fastfetch
fzf
zoxide
zsh
)

title() {

case "$1" in

aliases) echo "Shell Aliases";;
atuin) echo "Atuin";;
bash) echo "Bash";;
bat) echo "Bat";;
btop) echo "Btop";;
direnv) echo "Direnv";;
eza) echo "Eza";;
fastfetch) echo "Fastfetch";;
fzf) echo "FZF";;
zoxide) echo "Zoxide";;
zsh) echo "Zsh";;

esac

}

owns() {

case "$1" in

aliases) echo "home.shellAliases";;
atuin) echo "programs.atuin";;
bash) echo "programs.bash";;
bat) echo "programs.bat";;
btop) echo "programs.btop";;
direnv) echo "programs.direnv";;
eza) echo "programs.eza";;
fastfetch) echo "programs.fastfetch";;
fzf) echo "programs.fzf";;
zoxide) echo "programs.zoxide";;
zsh) echo "programs.zsh";;

esac

}

future() {

case "$1" in

aliases) echo "Infrastructure aliases, Git shortcuts, helper commands";;
atuin) echo "History sync, statistics";;
bash) echo "Interactive Bash configuration";;
bat) echo "Themes and pager";;
btop) echo "Theme and monitoring";;
direnv) echo "Nix integration";;
eza) echo "Icons and Git integration";;
fastfetch) echo "Startup dashboard";;
fzf) echo "Previews and completion";;
zoxide) echo "Directory navigation";;
zsh) echo "Plugins, history, completion, prompt";;

esac

}

##############################################################################
# Module generator
##############################################################################

for module in "${modules[@]}"; do

FILE="${SHELL_DIR}/${module}.nix"

[[ -f "$FILE" ]] && {
    echo "✓ ${module}.nix already exists"
    continue
}

cat > "$FILE" <<EOF
##############################################################################
#
# $(title "$module")
#
# Purpose
# -------
# Own every Home Manager option related to $(title "$module").
#
# Owns
# ----
# $(owns "$module")
#
# Future
# ------
# $(future "$module")
#
# Dependencies
# ------------
# None
#
# Migration
# ---------
# [ ] Move the corresponding configuration from home/ivali.nix
# [ ] Verify with:
#       nix fmt
#       nix flake check
# [ ] Remove duplicated configuration from home/ivali.nix
#
# Rules
# -----
# • One concern only.
# • Avoid cross-module configuration.
# • Split again if this file exceeds ~150 lines.
#
##############################################################################

{ ... }:

{

}
EOF

echo "Created ${module}.nix"

done

##############################################################################
# Summary
##############################################################################

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 Home Shell Module Layout

 home/
 └── shell/
     ├── default.nix
     ├── aliases.nix
     ├── atuin.nix
     ├── bash.nix
     ├── bat.nix
     ├── btop.nix
     ├── direnv.nix
     ├── eza.nix
     ├── fastfetch.nix
     ├── fzf.nix
     ├── zoxide.nix
     └── zsh.nix

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Migration Order

 1. aliases.nix
 2. bash.nix
 3. zsh.nix
 4. direnv.nix
 5. fzf.nix
 6. zoxide.nix
 7. atuin.nix
 8. bat.nix
 9. eza.nix
10. btop.nix
11. fastfetch.nix

After each migration:

    nix fmt
    nix flake check

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF


