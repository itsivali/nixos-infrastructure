##############################################################################
#
# Bitwarden Shell Completions
#
# Purpose
# -------
# Zsh, Bash, and Fish completions for all Bitwarden helper commands.
# Dynamic completion from cached vault items.
#
##############################################################################

{ config, pkgs, lib, ... }:

let
  cfg = config.ivali.bitwarden;
in
{
  config = lib.mkIf cfg.enable {
    programs.zsh.initContent = lib.mkAfter ''
      # ═══════════════════════════════════════════════════════════════════════
      # Dynamic Completion Source
      # ═══════════════════════════════════════════════════════════════════════

      _bw_complete_items() {
        local items
        items=$(bw-cache get 2>/dev/null)
        if [ -n "$items" ]; then
          echo "$items" | ${pkgs.jq}/bin/jq -r '.[].name' 2>/dev/null
        fi
      }

      _bw_complete_ids() {
        local items
        items=$(bw-cache get 2>/dev/null)
        if [ -n "$items" ]; then
          echo "$items" | ${pkgs.jq}/bin/jq -r '.[].id' 2>/dev/null
        fi
      }

      # ═══════════════════════════════════════════════════════════════════════
      # Zsh Completions
      # ═══════════════════════════════════════════════════════════════════════

      # bwfind
      _bwfind() {
        local -a commands
        commands=(${lib.concatMapStringsSep " " (x: "\"${x}\"") [
          "bwunlock"
          "bwlock"
          "bwlogout"
          "bwstatus"
          "bwsync"
          "bwfind"
          "bwp"
          "bwpass"
          "bwuser"
          "bwuri"
          "bwnotes"
          "bwtotp"
          "bwfav"
          "bw-cache"
        ]})

        if (( CURRENT == 2 )); then
          _describe -t commands 'Bitwarden commands' commands
        else
          _arguments '1:query:->query'
          _alternative \
            'queries:query:_bw_complete_items'
        fi
      }

      compdef _bwfind bwfind
      compdef _bwfind bwfind
      compdef _bwfind bwp
      compdef _bwfind bwpass
      compdef _bwfind bwuser
      compdef _bwfind bwuri
      compdef _bwfind bwnotes
      compdef _bwfind bwtotp

      # bwunlock, bwlock, bwlogout, bwstatus, bwsync — no arguments
      compdef '_arguments' bwunlock bwlock bwlogout bwstatus bwsync bwclear

      # bwfav
      _bwfav() {
        local -a commands
        commands=("add:Add to favorites" "rm:Remove from favorites" "list:List favorites")
        if (( CURRENT == 2 )); then
          _describe -t commands 'bwfav commands' commands
        else
          _alternative \
            'queries:query:_bw_complete_items'
        fi
      }
      compdef _bwfav bwfav

      # bw-cache
      _bwcache() {
        local -a commands
        commands=("update:Update cache" "get:Get cached items" "invalidate:Clear cache")
        _describe -t commands 'bw-cache commands' commands
      }
      compdef _bwcache bw-cache
    '';

    programs.bash.initExtra = lib.mkAfter ''
      # ═══════════════════════════════════════════════════════════════════════
      # Bash Completions
      # ═══════════════════════════════════════════════════════════════════════

      _bw_complete_bash() {
        local cur prev commands
        COMPREPLY=()
        cur="''${COMP_WORDS[COMP_CWORD]}"
        prev="''${COMP_WORDS[COMP_CWORD-1]}"
        commands="bwunlock bwlock bwlogout bwstatus bwsync bwfind bwp bwpass bwuser bwuri bwnotes bwtotp bwfav bw-cache"

        if [ "$COMP_CWORD" -eq 1 ]; then
          COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        else
          case "$prev" in
            bwfind|bwp|bwpass|bwuser|bwuri|bwnotes|bwtotp)
              COMPREPLY=($(compgen -W "$(_bw_complete_items 2>/dev/null)" -- "$cur"))
              ;;
            bwfav)
              COMPREPLY=($(compgen -W "add rm list" -- "$cur"))
              ;;
            bw-cache)
              COMPREPLY=($(compgen -W "update get invalidate" -- "$cur"))
              ;;
          esac
        fi
      }
      complete -F _bw_complete_bash bwfind bwp bwpass bwuser bwuri bwnotes bwtotp bwfav bw-cache
    '';

    programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
      bwu = "bwunlock";
      bwl = "bwlock";
      bwlo = "bwlogout";
      bws = "bwstatus";
      bwsy = "bwsync";
      bwf = "bwfind";
      bwc = "bwclear";
    };

    programs.fish.shellInit = lib.mkIf config.programs.fish.enable (lib.mkAfter ''
      # ═══════════════════════════════════════════════════════════════════════
      # Fish Completions
      # ═══════════════════════════════════════════════════════════════════════

      complete -c bwfind -f -a "(_bw_complete_items 2>/dev/null)"
      complete -c bwp -f -a "(_bw_complete_items 2>/dev/null)"
      complete -c bwpass -f -a "(_bw_complete_items 2>/dev/null)"
      complete -c bwuser -f -a "(_bw_complete_items 2>/dev/null)"
      complete -c bwuri -f -a "(_bw_complete_items 2>/dev/null)"
      complete -c bwnotes -f -a "(_bw_complete_items 2>/dev/null)"
      complete -c bwtotp -f -a "(_bw_complete_items 2>/dev/null)"
      complete -c bwfav -f -a "add rm list"
      complete -c bw-cache -f -a "update get invalidate"
    '');
  };
}
