##############################################################################
#
# Development Aliases
#
# Purpose
# -------
# Developer tool shortcuts for Go, databases, clipboard, and general
# productivity tools installed on this system.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for development tools
#
# Note
# ----
# Only aliases for packages actually installed on the system are included.
# Removed: kubectl, helm, terraform, ansible, docker (not installed).
#
##############################################################################

{ ... }:

{
  programs.zsh.shellAliases = {
    # ── Clipboard ─────────────────────────────────────────────────────
    clip = "wl-copy";
    cclip = "wl-paste";
    cclear = "wl-copy --clear";

    # ── Go ────────────────────────────────────────────────────────────
    gob = "go build";
    gor = "go run";
    got = "go test";
    gom = "go mod tidy";
    gow = "go work";
    gocov = "go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out";

    # ── Databases ─────────────────────────────────────────────────────
    vr = "valkey-cli";

    # ── OpenCode ──────────────────────────────────────────────────────
    oc = "opencode";

    # ── System Info ───────────────────────────────────────────────────
    ff = "fastfetch";

    # ── Process Monitoring ────────────────────────────────────────────
    lg = "lazygit";
    bt = "btop";
    gi = "gitui";

    # ── Editors ───────────────────────────────────────────────────────
    v = "nvim";
    vi = "nvim";

    # ── Shell ─────────────────────────────────────────────────────────
    reload = "exec zsh";

    # ── Python ────────────────────────────────────────────────────────
    py = "python";
    serve = "python -m http.server";

    # ── JSON / Data ───────────────────────────────────────────────────
    json = "jq";

    # ── Just ──────────────────────────────────────────────────────────
    j = "just";

    # ── Secrets ───────────────────────────────────────────────────────
    sopsl = "sops --decrypt";

    # ── GitLab CLI ────────────────────────────────────────────────────
    glmr = "glab mr list";
    glmrc = "glab mr create";

    # ── Nix Utilities ─────────────────────────────────────────────────
    nixsh = "nix-shell --packages";
    nixrun = "nix run nixpkgs#";

    # ── Process / Port Inspection ─────────────────────────────────────
    psg = "ps aux | grep";
    ports = "ss -tulpn";
    portse = "ss -tulpn | grep";
  };
}
