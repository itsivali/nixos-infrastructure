{ pkgs, ... }:

let
  cursorPackage = pkgs.code-cursor or pkgs.cursor or pkgs.vscode;
  tsxPackage = pkgs.nodePackages_latest.tsx or pkgs.nodePackages.tsx;
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
    attic-client
    cosign
    cursorPackage
    docker-buildx
    docker-compose
    flutter
    gitlab-runner
    go
    nodejs_22
    opentofu
    python312
    python312Packages.pip
    python312Packages.virtualenv
    syft
    terraform
    # Modern TypeScript runner; the legacy runner is intentionally omitted.
    tsxPackage
    yarn
  ];

  environment.variables = {
    EDITOR = "code --wait";
  };
}
