# developer/default.nix
#
# System-level developer tooling.
# Shell configuration is intentionally NOT set here — Home Manager owns
# programs.zsh and programs.bash for the ivali user. This module only sets
# the default login shell and installs system-wide packages.
{ pkgs, ... }:

let
  tsxPackage = pkgs.tsx;
in
{
  # ── shell ──────────────────────────────────────────────────────────────────
  # Just set the default shell; HM handles zsh options, aliases, plugins.
  programs.bash.completion.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # zsh must still be enabled at the system level so /etc/shells is updated
  # and login works before Home Manager activates. Options are left to HM.
  programs.zsh.enable = true;

  # ── virtualisation ─────────────────────────────────────────────────────────
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # ── packages ───────────────────────────────────────────────────────────────
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
    # pip, virtualenv, setuptools, wheel are no longer exposed as individual
    # python3XPackages attributes in nixos-unstable. Use uv for all venv /
    # package management instead — it is faster and already included.
    python313
    python313Packages.ipython
    python313Packages.pytest
    uv
    ruff
    black
    mypy

    # Flutter / Dart
    flutter
    dart
  ];

  # EDITOR is set in Home Manager's sessionVariables so it is scoped to the
  # user session and does not conflict with root or other users.
}
