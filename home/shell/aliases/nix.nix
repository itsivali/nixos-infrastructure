##############################################################################
#
# NixOS / Home Manager Aliases
#
# Purpose
# -------
# NixOS and Home Manager management aliases.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for Nix operations
#
# Responsibilities
# ----------------
# - System rebuild (rebuild, test, boot, build, dry)
# - Flake management (update, check, fmt)
# - Home Manager switch (hm)
# - Store management (optimise, clean)
#
##############################################################################

{ config, ... }:

let
  repoDir = "${config.home.homeDirectory}/nixos-infrastructure";
in

{
  programs.zsh.shellAliases = {
    rebuild = "git -C ${repoDir} pull && sudo nixos-rebuild switch --flake ${repoDir}#prague";
    rebuildn = "sudo nixos-rebuild switch --flake ${repoDir}#prague --no-build";
    test = "sudo nixos-rebuild test --flake ${repoDir}#prague";
    boot = "sudo nixos-rebuild boot --flake ${repoDir}#prague";
    build = "sudo nixos-rebuild build --flake ${repoDir}#prague";
    dry = "sudo nixos-rebuild dry-run --flake ${repoDir}#prague";
    rollback = "sudo nixos-rebuild rollback";
    gens = "sudo nix-env -p /nix/var/nix/profiles/system --list-generations";
    update = "cd ${repoDir} && nix flake update";
    check = "cd ${repoDir} && nix flake check";
    checknb = "cd ${repoDir} && NIX_REMOTE= nix flake check --no-build";
    fmt = "cd ${repoDir} && nix fmt";
    doctor = "ivali doctor";
    hm = "nix build ${repoDir}#hm-activate && ./result/activate && rm result";
    optimise = "sudo nix store optimise";
    clean = "sudo nix-collect-garbage -d";

    # GitOps reconciler
    gitops = "sudo systemctl restart gitops-reconciler.service";
    gitopslog = "journalctl -fu gitops-reconciler.service";
    gitopsstop = "sudo systemctl stop gitops-reconciler.timer";
    gitopsstart = "sudo systemctl start gitops-reconciler.timer";

    # Telegram bot
    bot = "sudo systemctl restart ivali-bot-go.service";
    botlog = "journalctl -fu ivali-bot-go.service";
    botstatus = "systemctl status ivali-bot-go.service";
  };
}
