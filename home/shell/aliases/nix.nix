##############################################################################
#
# NixOS / System Aliases
#
# Purpose
# -------
# NixOS system management, service control, and infrastructure aliases.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for NixOS operations
#
# Responsibilities
# ----------------
# - System rebuild (rebuild, test, boot, build, dry, rollback)
# - Flake management (update, check, fmt)
# - Store management (optimise, clean, gens)
# - Service management (all systemd services)
# - Observability stack (prometheus, grafana, loki)
# - GitOps and CI (gitops, bot, runner)
# - Security (security, tailscale)
# - Infrastructure (valkey, health)
#
##############################################################################

{ config, ... }:

let
  repoDir = "${config.home.homeDirectory}/nixos-infrastructure";
  svc = name: "sudo systemctl restart ${name}";
  journal = name: "journalctl -fu ${name}";
  status = name: "systemctl status ${name}";
  stop = name: "sudo systemctl stop ${name}";
  start = name: "sudo systemctl start ${name}";
in

{
  programs.zsh.shellAliases = {
    # ── NixOS Rebuild ─────────────────────────────────────────────────
    rebuild = "git -C ${repoDir} pull && ${repoDir}/scripts/validate-hardware.sh && sudo nixos-rebuild switch --flake ${repoDir}#prague";
    hwcheck = "${repoDir}/scripts/validate-hardware.sh";
    rebuildn = "sudo nixos-rebuild switch --flake ${repoDir}#prague --no-build";
    test = "sudo nixos-rebuild test --flake ${repoDir}#prague";
    boot = "sudo nixos-rebuild boot --flake ${repoDir}#prague";
    build = "sudo nixos-rebuild build --flake ${repoDir}#prague";
    dry = "sudo nixos-rebuild dry-run --flake ${repoDir}#prague";
    rollback = "sudo nixos-rebuild rollback";
    hm = "nix build ${repoDir}#hm-activate && ./result/activate && rm result";

    # ── Flake Management ──────────────────────────────────────────────
    update = "cd ${repoDir} && nix flake update";
    update-pkgs = "cd ${repoDir} && nix flake update nixpkgs";
    check = "cd ${repoDir} && nix flake check";
    checknb = "cd ${repoDir} && NIX_REMOTE= nix flake check --no-build";
    fmt = "cd ${repoDir} && nix fmt";

    # ── Generations & Store ───────────────────────────────────────────
    gens = "sudo nix-env -p /nix/var/nix/profiles/system --list-generations";
    optimise = "sudo nix store optimise";
    clean = "sudo nix-collect-garbage -d";

    # ── Quick Deploy ──────────────────────────────────────────────────
    # Pull + rebuild + push in one shot
    deploy = "cd ${repoDir} && git pull && ${repoDir}/scripts/validate-hardware.sh && sudo nixos-rebuild switch --flake ${repoDir}#prague && git push";

    # ── Valkey (Redis) ────────────────────────────────────────────────
    valkey = status "valkey.service";
    valkeylog = journal "valkey.service";

    # ── Telegram Bot ──────────────────────────────────────────────────
    bot = svc "ivali-bot-go.service";
    botlog = journal "ivali-bot-go.service";
    botstatus = status "ivali-bot-go.service";
    botstop = stop "ivali-bot-go.service";

    # ── GitOps ────────────────────────────────────────────────────────
    gitops = svc "gitops-reconciler.service";
    gitopslog = journal "gitops-reconciler.service";
    gitopsstatus = status "gitops-reconciler.timer";
    gitopsstop = stop "gitops-reconciler.timer";
    gitopsstart = start "gitops-reconciler.timer";

    # ── Observability Stack ───────────────────────────────────────────
    promlog = journal "prometheus.service";
    promstatus = status "prometheus.service";
    graflog = journal "grafana.service";
    grafstatus = status "grafana.service";
    lokilog = journal "loki.service";
    lokistatus = status "loki.service";
    alertlog = journal "alertmanager.service";
    alertstatus = status "alertmanager.service";
    otellog = journal "opentelemetry-collector.service";
    otelstatus = status "opentelemetry-collector.service";
    alloylog = journal "alloy.service";
    alloystatus = status "alloy.service";
    nodeexplog = journal "prometheus-node-exporter.service";
    nodeexpstatus = status "prometheus-node-exporter.service";

    # ── Deployment Health ─────────────────────────────────────────────
    health = status "deployment-health.service";
    healthlog = journal "deployment-health.service";

    # ── GitLab Runner ─────────────────────────────────────────────────
    runner = status "gitlab-runner.service";
    runnerlog = journal "gitlab-runner.service";

    # ── Tailscale ─────────────────────────────────────────────────────
    ts = "tailscale status";
    tsup = "tailscale up";
    tsdown = "tailscale down";

    # ── Security ──────────────────────────────────────────────────────
    seclog = journal "security-scan.service";
    secstatus = status "security-scan.service";

    # ── Ivali CLI ─────────────────────────────────────────────────────
    doctor = "ivali doctor";
    iv = "ivali";

    # ── Journal Shortcuts ─────────────────────────────────────────────
    journ = "journalctl -f";
    journerr = "journalctl -p err -f";
    journboot = "journalctl -b -p err";
  };
}
