{ pkgs, ... }:

let
  cursorPackage = pkgs.code-cursor or pkgs.cursor or pkgs.vscode;
  tsxPackage = pkgs.tsx;
in
{
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.bash.completion.enable = true;
  users.defaultUserShell = pkgs.zsh;

  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    alejandra
    go
    nodejs_22
    terraform
    tsxPackage
    yarn
  ];

  environment.variables = {
    EDITOR = "code --wait";
  };
}
