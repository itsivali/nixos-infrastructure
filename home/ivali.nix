{ config, lib, pkgs, username, ... }:

{
  imports = [ ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
    packages = import ../packages/user { inherit pkgs; };
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Willis Ivali";
    userEmail = "willisivali@users.noreply.gitlab.com";
    extraConfig = {
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
      rebuild = "sudo nixos-rebuild switch --flake /home/${username}/nixos-infrastructure#laptop";
      test-rebuild = "sudo nixos-rebuild test --flake /home/${username}/nixos-infrastructure#laptop";
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
    extensions = with pkgs.vscode-extensions; [
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

  xdg.configFile."Code/User/settings.json".enable = false;
}
