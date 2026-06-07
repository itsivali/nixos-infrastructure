# home/ivali.nix
{ config, lib, pkgs, username, ... }:

let
  repoDir = "${config.home.homeDirectory}/nixos-infrastructure";

  autoFormatNix = pkgs.writeShellApplication {
    name = "auto-format-nix-repo";

    # git is required by `nix fmt` to resolve the repo root and respect
    # .gitignore. Without it the watcher exits immediately with an error.
    runtimeInputs = [
      pkgs.bash
      pkgs.git
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
        -- bash -lc "cd \"$repo\" && nix --extra-experimental-features 'nix-command flakes' fmt"
    '';
  };
in
{
  imports = [ ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    # Keep in sync with system.stateVersion in flake.nix for a fresh install.
    stateVersion = "26.05";

    packages = import ../packages/user { inherit pkgs; };

    # Set EDITOR here so it is user-scoped and does not conflict with root.
    sessionVariables = {
      EDITOR = "code --wait";
    };
  };

  programs.home-manager.enable = true;

  # Suppress HM/Nixpkgs release mismatch warning
  home.enableNixpkgsReleaseCheck = false;

  # ── git ────────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Wilis Ivali";
        email = "itsivali@outlook.com";
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      rerere.enabled = true;
    };
  };

  # ── shell ──────────────────────────────────────────────────────────────────
  # HM owns the full zsh configuration. The system module (developer/default.nix)
  # only sets programs.zsh.enable = true and users.defaultUserShell = pkgs.zsh.
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "eza -la --git";

      edit-config =
        "code /home/${username}/nixos-infrastructure";

      rebuild =
        "sudo nixos-rebuild switch --flake /home/${username}/nixos-infrastructure#prague";

      test-rebuild =
        "sudo nixos-rebuild test --flake /home/${username}/nixos-infrastructure#prague";
    };
  };

  programs.bash.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship.enable = true;
  programs.zoxide.enable = true;
  programs.fzf.enable = true;

  # ── VSCode ─────────────────────────────────────────────────────────────────
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    # mutableExtensionsDir = true lets you install extensions imperatively
    # (e.g. `code --install-extension github.copilot`) without them being
    # wiped on the next Home Manager switch.
    mutableExtensionsDir = true;

    # Use the flat `extensions` list, not `profiles.default.extensions`.
    # The profiles API was added in a recent HM release; the flat list works
    # across all supported versions and is equivalent for a single profile.
    #
    # github.copilot is intentionally omitted — it is not packaged in nixpkgs.
    # Install it once with: code --install-extension github.copilot
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

  # ── XDG ───────────────────────────────────────────────────────────────────
  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "text/plain" = [ "code.desktop" ];
      "text/x-nix" = [ "code.desktop" ];
      "application/json" = [ "code.desktop" ];
      "application/x-yaml" = [ "code.desktop" ];
    };
  };

  # Prevent HM from writing a read-only settings.json that conflicts with
  # VSCode's own settings sync / manual edits.
  xdg.configFile."Code/User/settings.json".enable = false;

  # ── auto-format service ────────────────────────────────────────────────────
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
