{ config, lib, pkgs, username, ... }:

let
  repoDir = "${config.home.homeDirectory}/nixos-infrastructure";
  autoFormatNix = pkgs.writeShellApplication {
    name = "auto-format-nix-repo";
    runtimeInputs = [
      pkgs.bash
      pkgs.nix
      pkgs.watchexec
    ];
    text = ''
      set -euo pipefail

      repo="${repoDir}"
      if [ ! -d "$repo" ]; then
        echo "Repository not found at $repo; waiting for install checkout." >&2
        exec sleep infinity
      fi

      exec watchexec \
        --watch "$repo" \
        --ignore "$repo/.git" \
        --debounce 1000ms \
        --restart \
        -- bash -lc 'cd "$0" && nix --extra-experimental-features "nix-command flakes" fmt' "$repo"
    '';
  };
in
{
  imports = [ ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
    packages = import ../packages/user { inherit pkgs; };
  };

  programs.home-manager.enable = true;

  home.enableNixpkgsReleaseCheck = false;

  programs.git = {
    enable = true;

    userEmail = "willisivali@users.noreply.gitlab.com";
    settings = {
      user = {
        name = "Willis Ivali";
        email = "itsivali@outlook.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      rerere.enabled = true;
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "eza -la --git";
      edit-config = "code /home/${username}/nixos-infrastructure";
      rebuild = "sudo nixos-rebuild switch --flake /home/${username}/nixos-infrastructure#prague";
      test-rebuild = "sudo nixos-rebuild test --flake /home/${username}/nixos-infrastructure#prague";
    };
  };

  programs.bash = {
    enable = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship.enable = true;
  programs.zoxide.enable = true;
  programs.fzf.enable = true;

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    mutableExtensionsDir = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      dbaeumer.vscode-eslint
      esbenp.prettier-vscode
      github.copilot
      golang.go
      jnoortheen.nix-ide
      ms-azuretools.vscode-docker
      ms-python.python
      ms-python.vscode-pylance
      redhat.vscode-yaml
    ];
  };

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

  systemd.user.services.nix-repo-auto-format = {
    Unit = {
      Description = "Automatically format Nix files in nixos-infrastructure";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${autoFormatNix}/bin/auto-format-nix-repo";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
