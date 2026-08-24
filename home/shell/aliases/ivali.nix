##############################################################################
#
# IVALI Control Plane Aliases
#
# Purpose
# -------
# Shortcuts for the IVALI NixOS infrastructure control plane CLI.
#
# Ownership
# ---------
# ivali control plane
#
# Responsibilities
# ----------------
# - System status, health, and diagnostics (ivs, ivd, ivh)
# - Repository operations (ivg, ivx, ivscan, iviv)
# - Deployment workflow (ivdep, ivreb, ivup, ivrec)
# - Security and observability (ivsec, ivobs, ivlogs)
# - Documentation (ivdoc)
# - Development workflow (flow, flow-start, flow-commit, flow-push, flow-mr,
#   flow-merge, flow-deploy, flow-pipeline, flow-validate, flow-rollback,
#   flow-quick, flow-status)
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    # ── Core ──────────────────────────────────────────────────────────
    iv = "ivali";
    ivs = "ivali status";
    ivd = "ivali doctor";
    ivv = "ivali verify";

    # ── Repository ────────────────────────────────────────────────────
    ivg = "ivali graph";
    ivx = "ivali explain";
    ivscan = "ivali scan";
    iviv = "ivali inventory";
    ivsearch = "ivali search";

    # ── Deployment ────────────────────────────────────────────────────
    ivdep = "ivali deploy";
    ivreb = "ivali rebuild";
    ivup = "ivali update";
    ivrec = "ivali reconcile";
    ivb = "ivali bootstrap";

    # ── Observability ─────────────────────────────────────────────────
    ivobs = "ivali observability";
    ivlogs = "ivali logs";
    ivmet = "ivali metrics";
    ivhealth = "ivali health";
    ivmon = "ivali monitor";

    # ── Security ──────────────────────────────────────────────────────
    ivsec = "ivali security";
    ivsecscan = "ivali security-scan";
    ivfw = "ivali firewall";

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

    # ── Other ─────────────────────────────────────────────────────────
    ivdoc = "ivali docs";
    ivdiff = "ivali diff";
    ivrem = "ivali remediation";
    ivrb = "ivali rollback";
    ivbk = "ivali backup";
    ivrs = "ivali restore";
    ivsuggest = "ivali suggest";
    ivai = "ivali ai";
    ivts = "ivali tailscale";
    ivsecrets = "ivali secrets";
    ivusers = "ivali users";
  };
}
