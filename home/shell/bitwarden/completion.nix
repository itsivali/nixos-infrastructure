##############################################################################
#
# Bitwarden Shell Completions
#
# Purpose
# -------
# Zsh, Bash, and Fish completions for the `bw` Go TUI binary and
# the `bwfind` wrapper.  Dynamic completion from cached vault items.
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

      # ═══════════════════════════════════════════════════════════════════════
      # Zsh Completions
      # ═══════════════════════════════════════════════════════════════════════

      _bw_subcommands() {
        local -a subcmds
        subcmds=("unlock:Unlock vault" "lock:Lock vault" "status:Show status" "sync:Sync vault" "logout:Log out")
        _describe -t subcommands 'bw subcommands' subcmds
      }

      _bw() {
        if (( CURRENT == 2 )); then
          _alternative \
            'subcommands:subcommand:_bw_subcommands' \
            'queries:search query:_bw_complete_items'
        fi
      }

      compdef _bw bw

      # bwfind — accepts vault item names as arguments
      _bwfind() {
        _arguments '1:search query:_bw_complete_items'
      }
      compdef _bwfind bwfind
    '';

    programs.bash.initExtra = lib.mkAfter ''
      # ═══════════════════════════════════════════════════════════════════════
      # Bash Completions
      # ═══════════════════════════════════════════════════════════════════════

      _bw_complete_bash() {
        local cur prev
        COMPREPLY=()
        cur="''${COMP_WORDS[COMP_CWORD]}"
        prev="''${COMP_WORDS[COMP_CWORD-1]}"

        if [ "$COMP_CWORD" -eq 1 ]; then
          COMPREPLY=($(compgen -W "unlock lock status sync logout" -- "$cur"))
          # Also suggest item names
          COMPREPLY+=($(compgen -W "$(_bw_complete_items 2>/dev/null)" -- "$cur"))
        fi
      }
      complete -F _bw_complete_bash bw

      _bwfind_bash() {
        local cur
        COMPREPLY=()
        cur="''${COMP_WORDS[COMP_CWORD]}"
        COMPREPLY=($(compgen -W "$(_bw_complete_items 2>/dev/null)" -- "$cur"))
      }
      complete -F _bwfind_bash bwfind
    '';

    programs.fish.shellAbbrs = lib.mkIf config.programs.fish.enable {
      bwu = "bw unlock";
      bwl = "bw lock";
      bws = "bw status";
      bwsy = "bw sync";
      bwlo = "bw logout";
      bwf = "bwfind";
    };

    programs.fish.shellInit = lib.mkIf config.programs.fish.enable (lib.mkAfter ''
      # ═══════════════════════════════════════════════════════════════════════
      # Fish Completions
      # ═══════════════════════════════════════════════════════════════════════

      complete -c bw -f -a "unlock lock status sync logout"
      complete -c bw -f -a "(_bw_complete_items 2>/dev/null)"
      complete -c bwfind -f -a "(_bw_complete_items 2>/dev/null)"
    '');
  };
}
