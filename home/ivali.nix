# home/ivali.nix
#
# Home Manager configuration for the primary development workstation.
#
# Features
# ─────────────────────────────────────────────────────────────────────────────
# • Powerlevel10k prompt
# • Zsh autosuggestions
# • Zsh syntax highlighting
# • Interactive completion
# • FZF integration
# • Zoxide
# • Git aliases
# • NixOS management aliases
# • Automatic Nix formatting service
# • VSCode
# • Direnv + nix-direnv
#


{ config, lib, pkgs, username, ... }:

let
  repoDir = "${config.home.homeDirectory}/nixos-infrastructure";

  autoFormatNix = pkgs.writeShellApplication {
    name = "auto-format-nix-repo";

    runtimeInputs = with pkgs; [
      bash
      git
      nix
      watchexec
    ];

    text = ''
      set -euo pipefail

      repo="${repoDir}"

      if [ ! -d "$repo" ]; then
        echo "Repository not found: $repo"
        exec sleep infinity
      fi

      exec watchexec \
        --watch "$repo" \
        --ignore "$repo/.git" \
        --debounce 1000ms \
        --restart \
        -- bash -lc \
        "cd \"$repo\" && nix --extra-experimental-features 'nix-command flakes' fmt"
    '';
  };

in
{

  ##############################################################################
  # Imports
  ##############################################################################

  imports = [ ./fonts.nix ];

  ##############################################################################
  # Home
  ##############################################################################

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.11";

    packages = (import ../packages/user { inherit pkgs; }) ++ (with pkgs; [
      # Shell
      zsh-powerlevel10k
      zsh-completions

      # Better CLI
      eza
      bat
      fd
      ripgrep
      tree
      fzf
      delta

      # Monitoring
      btop
      fastfetch

      # Git
      lazygit
    ]);

    sessionVariables = {
      EDITOR = "code --wait";
      VISUAL = "code --wait";
      PAGER = "bat";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
      LESS = "-R";
    };
  };

  ##############################################################################
  # Home Manager
  ##############################################################################

  programs.home-manager.enable = true;
  home.enableNixpkgsReleaseCheck = false;

  ##############################################################################
  # Git
  ##############################################################################

  programs.git = {
    enable = true;

    delta = {
      enable = true;
    };

    lfs.enable = true;

    ignores = [
      ".DS_Store"
      "*.swp"
      "*.tmp"
      "result"
    ];

    settings = {
      user = {
        name = "Wilis Ivali";
        email = "itsivali@outlook.com";
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      rerere.enabled = true;
      push.autoSetupRemote = true;
      fetch.prune = true;

      core = {
        editor = "code --wait";
      };

      color.ui = true;
      merge.conflictstyle = "zdiff3";
    };
  };

  ##############################################################################
  # ZSH
  ##############################################################################

  programs.zsh = {
    enable = true;
    autocd = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 100000;
      save = 100000;
      path = "${config.xdg.dataHome}/zsh/history";
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
      extended = true;
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "zsh-completions";
        src = pkgs.zsh-completions;
      }
    ];

    shellAliases = {
      ###########################################################################
      # Navigation
      ###########################################################################
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      home = "cd ~";
      cfg = "cd ${repoDir}";
      edit = "code ${repoDir}";

      ###########################################################################
      # Listing
      ###########################################################################
      ls = "eza";
      ll = "eza -lah --icons --git";
      la = "eza -a";
      lt = "eza --tree";
      l = "eza -lh";
      cat = "bat";

      ###########################################################################
      # Git
      ###########################################################################
      g = "git";
      gs = "git status";
      ga = "git add";
      gaa = "git add .";
      gc = "git commit";
      gcm = "git commit -m";
      gp = "git push";
      gpl = "git pull";
      gd = "git diff";
      gl = "git log --graph --decorate --oneline";
      gb = "git branch";
      gco = "git checkout";
      gst = "git stash";
      gcap = "git add . && git commit && git push";

      ###########################################################################
      # NixOS / Home Manager
      ###########################################################################
      rebuild = "sudo nixos-rebuild switch --flake ${repoDir}#prague";
      test = "sudo nixos-rebuild test --flake ${repoDir}#prague";
      boot = "sudo nixos-rebuild boot --flake ${repoDir}#prague";
      build = "sudo nixos-rebuild build --flake ${repoDir}#prague";
      dry = "sudo nixos-rebuild dry-run --flake ${repoDir}#prague";
      update = "cd ${repoDir} && nix flake update";
      check = "cd ${repoDir} && nix flake check";
      fmt = "cd ${repoDir} && nix fmt";
      hm = "home-manager switch --flake ${repoDir}";
      optimise = "sudo nix store optimise";
      clean = "sudo nix-collect-garbage -d";

      ###########################################################################
      # Development
      ###########################################################################
      ff = "fastfetch";
      lg = "lazygit";
      bt = "btop";
      rg = "rg";
      f = "fd";
      reload = "exec zsh";
      cls = "clear";
      h = "history";
    };

    ############################################################################
    # ZSH Startup
    ############################################################################
    initContent = ''
      ######################################################################
      # Powerlevel10k Instant Prompt
      ######################################################################
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${USER}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${USER}.zsh"
      fi

      ######################################################################
      # Completion
      ######################################################################
      autoload -Uz compinit
      compinit

      zstyle ':completion:*' matcher-list \
          'm:{a-z}={A-Za-z}' \
          'r:|=*' \
          'l:|=* r:|=*'

      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"

      ######################################################################
      # Better key bindings
      ######################################################################
      bindkey '^I' menu-expand-or-complete
      bindkey '^[[A' up-line-or-search
      bindkey '^[[B' down-line-or-search

      ######################################################################
      # FZF
      ######################################################################
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh

      ######################################################################
      # Zoxide
      ######################################################################
      eval "$(zoxide init zsh)"

      ######################################################################
      # Handy options
      ######################################################################
      setopt AUTO_CD
      setopt AUTO_PUSHD
      setopt PUSHD_IGNORE_DUPS
      setopt HIST_IGNORE_DUPS
      setopt HIST_IGNORE_SPACE
      setopt HIST_VERIFY
      setopt SHARE_HISTORY
      setopt EXTENDED_HISTORY
      setopt INC_APPEND_HISTORY

      ######################################################################
      # Useful completion colors
      ######################################################################
      export LS_COLORS=$(${pkgs.coreutils}/bin/dircolors -b)

      ######################################################################
      # Load user Powerlevel10k configuration
      ######################################################################
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
    '';
  };

  ##############################################################################
  # Bash
  ##############################################################################

  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  ##############################################################################
  # Direnv
  ##############################################################################

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  ##############################################################################
  # FZF
  ##############################################################################

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  ##############################################################################
  # Zoxide
  ##############################################################################

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  ##############################################################################
  # Starship
  ##############################################################################

  # Powerlevel10k replaces Starship.
  programs.starship.enable = false;

  ##############################################################################
  # VS Code
  ##############################################################################

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    mutableExtensionsDir = true;

    extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      dbaeumer.vscode-eslint
      esbenp.prettier-vscode
      golang.go
      jnoortheen.nix-ide
      ms-azuretools.vscode-docker
      ms-python.python
      ms-python.vscode-pylance
      redhat.vscode-yaml
    ];
  };

  ##############################################################################
  # XDG
  ##############################################################################

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "text/plain" = [ "code.desktop" ];
      "text/x-nix" = [ "code.desktop" ];
      "application/json" = [ "code.desktop" ];
      "application/x-yaml" = [ "code.desktop" ];
    };
  };

  xdg.configFile."Code/User/settings.json".enable = false;

  ##############################################################################
  # Automatic Nix Repository Formatting
  ##############################################################################

  systemd.user.services.nix-repo-auto-format = {
    Unit = {
      Description = "Automatically format Nix files in nixos-infrastructure";
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${autoFormatNix}/bin/auto-format-nix-repo";
      Restart = "on-failure";
      RestartSec = "5s";

      # Lower CPU priority so formatting never interferes with normal work.
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

}
