{ pkgs, ... }:

let
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

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  environment.systemPackages = with pkgs; [
    # Nix
    alejandra

    # Go
    go

    # Node.js / TypeScript
    nodejs_22
    yarn
    typescript
    typescript-language-server
    tsxPackage

    # Python
    python313
    python313Packages.pip
    python313Packages.virtualenv
    python313Packages.setuptools
    python313Packages.wheel
    python313Packages.ipython
    python313Packages.pytest
    uv
    ruff
    black
    mypy

    # Flutter / Dart
    flutter
    dart

    # Infrastructure

  ];

  environment.variables = {
    EDITOR = "code --wait";
  };
}
