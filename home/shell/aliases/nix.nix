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
# - GitOps and CI (gitops, runner)
# - Security (security, tailscale)
# - Infrastructure (valkey, health)
# - Development workflow (flow, flow-start, flow-commit, flow-push, flow-mr,
#   flow-merge, flow-deploy, flow-pipeline, flow-validate, flow-rollback,
#   flow-quick, flow-status)
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
    rebuild = "${repoDir}/scripts/rebuild.sh";
    hwcheck = "${repoDir}/scripts/validate-hardware.sh";
    check-hashes = "${repoDir}/scripts/update-go-hashes.sh --verify-only";
    fix-hashes = "${repoDir}/scripts/update-go-hashes.sh";
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

    # ── Development Workflow ──────────────────────────────────────────
    # Full workflow: start → commit → push → mr → merge → deploy
    flow = "ivali flow";
    flow-start = "ivali flow start";
    flow-commit = "ivali flow commit";
    flow-push = "ivali flow push";
    flow-mr = "ivali flow mr";
    flow-merge = "ivali flow merge";
    flow-deploy = "ivali flow deploy";
    flow-status = "ivali flow status";
    flow-pipeline = "ivali flow pipeline";
    flow-validate = "ivali flow validate";
    flow-rollback = "ivali flow rollback";
    flow-quick = "ivali flow quick";

    # Quick workflow shortcuts (interactive menus)
    newfeature = "ivali flow start feature";
    newbugfix = "ivali flow start bugfix";
    newmodule = "ivali flow start module";
    newsecurity = "ivali flow start security";
    newarch = "ivali flow start architecture";
    newdocs = "ivali flow start docs";

    # With AI integration (calls opencode)
    newfeature-ai = "ivali flow start feature --ai";
    newbugfix-ai = "ivali flow start bugfix --ai";
    newmodule-ai = "ivali flow start module --ai";
    newsecurity-ai = "ivali flow start security --ai";
    newarch-ai = "ivali flow start architecture --ai";
    newdocs-ai = "ivali flow start docs --ai";

    # AI + Implement (opencode writes the code)
    newfeature-ai-impl = "ivali flow start feature --ai --implement";
    newbugfix-ai-impl = "ivali flow start bugfix --ai --implement";
    newmodule-ai-impl = "ivali flow start module --ai --implement";
    newsecurity-ai-impl = "ivali flow start security --ai --implement";
    newarch-ai-impl = "ivali flow start architecture --ai --implement";
    newdocs-ai-impl = "ivali flow start docs --ai --implement";

    # Deploy with options
    deploy-dry = "ivali flow deploy --dry-run";
    deploy-quick = "ivali flow deploy --skip-checks";

    # ── Valkey (Redis) ────────────────────────────────────────────────
    valkey = status "valkey.service";
    valkeylog = journal "valkey.service";

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
