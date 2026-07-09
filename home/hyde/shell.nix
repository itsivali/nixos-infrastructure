{ config, lib, pkgs, hyde-configs, ... }:

let
  cfg = config.hydenix.hm;
  hc = hyde-configs;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      zsh
      zsh-powerlevel10k
    ];

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      initExtra = ''
        # Load HyDE shell environment
        export ZSH="$HOME/.local/share/hyde/zsh"
        if [ -f "$ZSH/.zshrc" ]; then
          source "$ZSH/.zshrc"
        fi

        # Powerlevel10k instant prompt
        if [[ -r "$HOME/.p10k.zsh" ]]; then
          source "$HOME/.p10k.zsh"
        fi
      '';
    };

    home.file = {
      ".local/share/hyde/zsh" = {
        source = "${hc}/Configs/.local/share/hyde/zsh";
        recursive = true;
        force = true;
        mutable = true;
      };
    };
  };
}
