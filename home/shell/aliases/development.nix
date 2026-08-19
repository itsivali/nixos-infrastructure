##############################################################################
#
# Development Aliases
#
# Purpose
# -------
# Developer tool shortcuts for Go, databases, clipboard, cloud CLIs,
# and general productivity tools installed on this system.
#
# Ownership
# ---------
# programs.zsh.shellAliases entries for development tools
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

    # ── Editors ───────────────────────────────────────────────────────
    v = "nvim";
    vi = "nvim";

    # ── Finders ───────────────────────────────────────────────────────
    f = "fd";
    fzfh = "fzf --tac --height 40% --bind 'ctrl-x:execute(echo {} | xargs xdg-open)'";

    # ── Databases ─────────────────────────────────────────────────────
    vr = "valkey-cli";

    # ── OpenCode ──────────────────────────────────────────────────────
    oc = "opencode";

    # ── Process Monitoring ────────────────────────────────────────────
    lg = "lazygit";
    gi = "gitui";

    # ── System Info ───────────────────────────────────────────────────
    ff = "fastfetch";

    # ── Python ────────────────────────────────────────────────────────
    py = "python3";
    serve = "python3 -m http.server";

    # ── JSON / Data ───────────────────────────────────────────────────
    json = "jq";

    # ── Just ──────────────────────────────────────────────────────────
    j = "just";

    # ── Sync / Watch ──────────────────────────────────────────────────
    rs = "rsync -avz --progress";
    we = "watchexec";

    # ── Encryption / Secrets ──────────────────────────────────────────
    sopsl = "sops --decrypt";
    aged = "age --decrypt";
    agee = "age -r";
    gpge = "gpg --encrypt";
    gpgd = "gpg --decrypt";

    # ── GitHub CLI ────────────────────────────────────────────────────
    ghpr = "gh pr list";
    ghprc = "gh pr create";
    ghi = "gh issue list";
    ghic = "gh issue create";
    ghr = "gh repo view";

    # ── GitLab CLI ────────────────────────────────────────────────────
    glmr = "glab mr list";
    glmrc = "glab mr create";

    # ── Cloud CLIs ────────────────────────────────────────────────────
    gcssh = "gcloud compute ssh";
    gcls = "gcloud compute list";
    vlt = "vault";
    vread = "vault read";
    vwrite = "vault write";
    ar = "argocd";
    arapp = "argocd app list";
    arsync = "argocd app sync";

    # ── Infrastructure ────────────────────────────────────────────────
    pk = "packer";
    con = "consul";

    # ── Ansible ───────────────────────────────────────────────────────
    an = "ansible";
    ap = "ansible-playbook";
    ali = "ansible-lint";
    ag = "ansible-galaxy";

    # ── Shell ─────────────────────────────────────────────────────────
    reload = "exec zsh";

    # ── Nix Utilities ─────────────────────────────────────────────────
    nixsh = "nix-shell --packages";
    nixrun = "nix run nixpkgs#";

    # ── Process / Port Inspection ─────────────────────────────────────
    psg = "ps aux | grep";
    ports = "ss -tulpn";
    portse = "ss -tulpn | grep";
  };
}
